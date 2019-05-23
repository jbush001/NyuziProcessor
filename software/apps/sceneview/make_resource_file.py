#!/usr/bin/env python3
#
# Copyright 2011-2015 Jeff Bush
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

"""Read a Wavefront .OBJ file and convert it into a flat file.

The output is read by the viewer program.
"""

import math
import os
import re
import struct
import sys
from PIL import Image

NUM_MIP_LEVELS = 4

# This is the final output of the parsing stage
texture_list = []  # (width, height, data)
mesh_list = []		# (texture index, vertex list, index list)

material_name_to_texture_idx = {}
texture_file_to_texture_idx = {}

size_re1 = re.compile(r'Geometry: (?P<width>\d+)x(?P<height>\d+)')  # JPEG
size_re2 = re.compile(
    r'PNG width: (?P<width>\d+), height: (?P<height>\d+)')  # PNG


def read_image_file(filename, resize_to_width=None, resize_to_height=None):
    """Read and decode an image in the local filesystem.

    Args:
        filename: str
            Path to image file.
        resize_to_width: int
            If specified, this will be the new width of the resulting image.
            If the source image is not this size, the image will be scaled.
        resize_to_height: int
            This must be specified if resize_to_width is, and gives the
            vertical dimension of the loaded image.

    Returns:
        (width: int, height: int, raster data:bytes )

    Raises:
        Exception if there is a problem reading or decoding the file.
    """

    image = Image.open(filename)
    if resize_to_width is not None:
        image = image.resize((resize_to_width, resize_to_height), Image.BICUBIC)


    return (image.size[0], image.size[1], image.convert("RGBA").tobytes())


def read_texture(filename):
    """Read an image file at multiple resolutions to create mip maps

    This is read at the original resolution, then progressively at scaled
    down by halves for MIP map levels. These will be stored as RGBA 32-bit
    raster data.

    Args:
        filename: string
            Path to file to open.

    Returns:
        (width: int, height: int, image data: bytes)
    """
    print('read texture ' + filename)
    width, height, data = read_image_file(filename)

    # Read in lower mip levels
    for level in range(1, NUM_MIP_LEVELS + 1):
        _, _, sub_data = read_image_file(
            filename, width >> level, height >> level)
        data += sub_data

    return width, height, data


def read_mtl_file(filename):
    """Read a material file

    As a side effect, this will also read in the texture files specified
    in the file. These will be cached, so if the same file appears in
    multiple materials, the same loaded images will be used. This will
    update global variables indexing the textures and materials as a side
    effect.

    Args:
        filename: str
            Path fo file to open

    Returns:
        Nothing.
    """
    global material_name_to_texture_idx
    global texture_file_to_texture_idx

    print('read material file ' + filename)

    current_name = ''
    with open(filename) as f:
        for line in f:
            if line[0] == '#' or line.strip() == '':
                continue

            fields = [s for s in line.strip().split(' ') if s]
            if fields[0] == 'newmtl':
                current_name = fields[1]
                material_name_to_texture_idx[fields[1]] = -1
            elif fields[0] == 'map_Kd':
                texture_file = fields[1]
                if texture_file in texture_file_to_texture_idx:
                    # We've already used this texture, just tag the same ID
                    material_name_to_texture_idx[
                        current_name] = texture_file_to_texture_idx[texture_file]
                else:
                    # load a new texture
                    material_name_to_texture_idx[
                        current_name] = len(texture_list)
                    texture_file_to_texture_idx[
                        texture_file] = len(texture_list)
                    texture_name = os.path.join(os.path.dirname(filename), fields[1])
                    texture_list.append(read_texture(texture_name))


def compute_normal(vertex1, vertex2, vertex3):
    """Compute a vector perpendicular to the face of a triangle in 3d space.

    Args:
        vertex1: (float, float, float)
            Position of first triangle point.
        vertex1: (float, float, float)
            Position of second triangle point.
        vertex1: (float, float, float)
            Position of third triangle point.
    Returns:
        (float, float, float) A vector (from origin) describing the orientation
        of the normal.

    Raises:
        Nothing
    """

    # Vector 1
    ax = vertex2[0] - vertex1[0]
    ay = vertex2[1] - vertex1[1]
    az = vertex2[2] - vertex1[2]

    # Vector 2
    bx = vertex3[0] - vertex1[0]
    by = vertex3[1] - vertex1[1]
    bz = vertex3[2] - vertex1[2]

    # Cross product
    cx = ay * bz - az * by
    cy = az * bx - ax * bz
    cz = ax * by - ay * bx

    # Normalize
    mag = math.sqrt(cx * cx + cy * cy + cz * cz)
    if mag == 0:
        return (0, 0, 0)

    return (cx / mag, cy / mag, cz / mag)


def obj_to_py_index(x):
    """Convert OBJ index to python array index.

    If index > 0, then it is the offset from the beginning of the vertex
    list, starting at 1. If index < 0, it references from the end of the list,
    starting at -1.
    """
    return x + 1 if x < 0 else x - 1


def read_obj_file(filename):
    """Read a Wavefront .OBJ file containing geometry data.

    This may read other files containing materials and textures as a
    side effect. It updates a global variable with the contents of the
    meshes.

    Args:
        filename: str
            Path to file

    Returns:
        Nothing
    """

    global mesh_list

    vertex_positions = []
    texture_coordinates = []
    normals = []
    combined_vertices = []
    vertex_to_index = {}
    triangle_index_list = []
    current_texture_id = -1

    with open(filename, 'r') as f:
        for line in f:
            if line[0] == '#' or line.strip() == '':
                continue

            fields = [s for s in line.strip().split(' ') if s]
            if fields[0] == 'v':
                vertex_positions.append(
                    (float(fields[1]), float(fields[2]), float(fields[3])))
            elif fields[0] == 'vt':
                texture_coordinates.append(
                    (float(fields[1]), float(fields[2])))
            elif fields[0] == 'vn':
                normals.append(
                    (float(fields[1]), float(fields[2]), float(fields[3])))
            elif fields[0] == 'f':
                # The OBJ file references vertex_positions and texture
                # coordinates independently. They must be paired in our
                # implementation. Build a new vertex list that
                # combines those and generate an index list into that.

                # Break the strings 'vertex_index/texture_index' into a list and
                # convert to 0 based array (OBJ is 1 based)
                parsed_indices = []
                for index_tuple in fields[1:]:
                    parsed_indices.append([obj_to_py_index(int(x))
                        if x else '' for x in index_tuple.split('/')])

                if len(parsed_indices[0]) < 3:
                    # This file does not contain normals.  Generate a face
                    # normal that we will substitute.
                    # XXX this isn't perfect because the vertex normal should
                    # be the combination of all face normals, but it's good
                    # enough for our purposes.
                    face_normal = compute_normal(
                        vertex_positions[parsed_indices[0][0]],
                        vertex_positions[parsed_indices[1][0]],
                        vertex_positions[parsed_indices[2][0]])
                else:
                    face_normal = None

                # Create a new vertex array that combines the attributes
                polygon_indices = []
                for indices in parsed_indices:
                    vertex_attrs = vertex_positions[indices[0]]
                    if len(indices) > 1 and indices[1]:
                        vertex_attrs += texture_coordinates[indices[1]]
                    else:
                        vertex_attrs += (0, 0)

                    if face_normal is not None:
                        vertex_attrs += face_normal
                    else:
                        vertex_attrs += normals[indices[2]]

                    if vertex_attrs not in vertex_to_index:
                        vertex_to_index[vertex_attrs] = len(combined_vertices)
                        combined_vertices += [vertex_attrs]

                    polygon_indices += [vertex_to_index[vertex_attrs]]

                # face_list is made up of polygons. Convert to triangles.
                for index in range(1, len(polygon_indices) - 1):
                    triangle_index_list += [
                        polygon_indices[0],
                        polygon_indices[index],
                        polygon_indices[index + 1]
                    ]
            elif fields[0] == 'usemtl':
                # Switch material
                new_texture_id = material_name_to_texture_idx[fields[1]]
                if new_texture_id != current_texture_id:
                    if triangle_index_list:
                        # State change, emit current primitives and clear the
                        # current combined list
                        mesh_list += [(current_texture_id,
                                       combined_vertices, triangle_index_list)]
                        combined_vertices = []
                        vertex_to_index = {}
                        triangle_index_list = []
                    current_texture_id = new_texture_id
            elif fields[0] == 'mtllib':
                path = os.path.join(os.path.dirname(filename), fields[1])
                read_mtl_file(path)

        if triangle_index_list:
            mesh_list += [(current_texture_id, combined_vertices,
                           triangle_index_list)]


def print_stats():
    """Print geometric information about the file that was just read.

    This assumes read_obj_file has already been called. It uses information
    stored in global variables.

    Args:
        None

    Returns:
        Nothing

    Raises:
        Nothing
    """
    total_triangles = 0
    total_vertices = 0
    minx = float('Inf')
    maxx = float('-Inf')
    miny = float('Inf')
    maxy = float('-Inf')
    minz = float('Inf')
    maxz = float('-Inf')

    for _, vertices, indices in mesh_list:
        total_triangles += len(indices) // 3
        total_vertices += len(vertices)
        for x, y, z, _, _, _, _, _ in vertices:
            minx = min(x, minx)
            miny = min(y, miny)
            minz = min(z, minz)
            maxx = max(x, maxx)
            maxy = max(y, maxy)
            maxz = max(z, maxz)

    print('meshes ' + str(len(mesh_list)))
    print('triangles ' + str(total_triangles))
    print('vertices ' + str(total_vertices))
    print('scene bounds ')
    print('  x {} {}'.format(minx, maxx))
    print('  y {} {}'.format(miny, maxy))
    print('  z {} {}'.format(minz, maxz))


def align(addr, alignment):
    return int((addr + alignment - 1) // alignment) * alignment


def write_resource_file(filename):
    """Write all geometry and texture information into a unified binary file.

    This custom format is read by the sceneviewer application.

    Args:
        filename: str
            Path to file in host filesystem to write.

    Returns:
        Nothing

    Raises:
        IOException if there is a problem writing to the file.
    """
    current_data_offset = 12 + len(texture_list) * \
        12 + len(mesh_list) * 16  # Skip header
    current_header_offset = 12

    with open(filename, 'wb') as f:
        # Write textures
        for width, height, data in texture_list:
            # Write file header
            f.seek(current_header_offset)
            f.write(struct.pack('iihh', current_data_offset,
                                NUM_MIP_LEVELS, width, height))
            current_header_offset += 12

            # Write data
            f.seek(current_data_offset)
            f.write(data)
            current_data_offset = align(current_data_offset + len(data), 4)

        # Write meshes
        for texture_idx, vertices, indices in mesh_list:
            current_data_offset = align(current_data_offset, 4)

            # Write file header
            f.seek(current_header_offset)
            f.write(struct.pack('iiii', current_data_offset,
                                texture_idx, len(vertices), len(indices)))
            current_header_offset += 16

            # Write data
            f.seek(current_data_offset)
            for vert in vertices:
                for val in vert:
                    f.write(struct.pack('f', val))
                    current_data_offset += 4

            for index in indices:
                f.write(struct.pack('I', index))
                current_data_offset += 4

        # Write file header
        f.seek(0)
        f.write(struct.pack('I', current_data_offset))  # total size
        f.write(struct.pack('I', len(texture_list)))  # num textures
        f.write(struct.pack('I', len(mesh_list)))  # num meshes

        print('wrote ' + filename)

def main():
    if len(sys.argv) < 2:
        print('enter the name of a .OBJ file')
        sys.exit(1)

    read_obj_file(sys.argv[1])
    print_stats()
    write_resource_file('resource.bin')

if __name__ == '__main__':
    main()
