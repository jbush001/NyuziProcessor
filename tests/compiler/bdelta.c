/*
 * Copyright (C) 2011 Joseph Adams <joeyadams3.14159@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

// Downloaded from https://ccodearchive.net/info/bdelta.html

#include <stddef.h>
#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
	BDELTA_OK               = 0,  /* Operation succeeded. */

	BDELTA_MEMORY           = 1,  /* Memory allocation failed. */
	BDELTA_PATCH_INVALID    = 2,  /* Patch is malformed. */
	BDELTA_PATCH_MISMATCH   = 3,  /* Patch applied to wrong original string. */

	/* Internal error codes.  These will never be returned by API functions. */
	BDELTA_INTERNAL_DMAX_EXCEEDED    = -10,
	BDELTA_INTERNAL_INPUTS_TOO_LARGE = -11,
} BDELTAcode;

/*
 * bdelta_diff - Given two byte strings, generate a "patch" (also a byte string)
 * that describes how to transform the old string into the new string.
 *
 * On success, returns BDELTA_OK, and passes a malloc'd block
 * and its size through *patch_out and *patch_size_out.
 *
 * On failure, returns an error code, and clears *patch_out and *patch_size_out.
 *
 * Example:
 *	const char *old = "abcabba";
 *	const char *new_ = "cbabac";
 *	void *patch;
 *	size_t patch_size;
 *	BDELTAcode rc;
 *
 *	rc = bdelta_diff(old, strlen(old), new_, strlen(new_), &patch, &patch_size);
 *	if (rc != BDELTA_OK) {
 *		bdelta_perror("bdelta_diff", rc);
 *		return;
 *	}
 *	...
 *	free(patch);
 */
BDELTAcode bdelta_diff(
	const void  *old,       size_t  old_size,
	const void  *new_,      size_t  new_size,
	void       **patch_out, size_t *patch_size_out
);

/*
 * bdelta_patch - Apply a patch produced by bdelta_diff to the
 * old string to recover the new string.
 *
 * On success, returns BDELTA_OK, and passes a malloc'd block
 * and its size through *new_out and *new_size_out.
 *
 * On failure, returns an error code, and clears *new_out and *new_size_out.
 *
 * Example:
 *	const char *old = "abcabba";
 *	void *new_;
 *	size_t new_size;
 *	BDELTAcode rc;
 *
 *	rc = bdelta_patch(old, strlen(old), patch, patch_size, &new_, &new_size);
 *	if (rc != BDELTA_OK) {
 *		bdelta_perror("bdelta_patch", rc);
 *		return;
 *	}
 *	fwrite(new_, 1, new_size, stdout);
 *	putchar('\n');
 *	free(new_);
 */
BDELTAcode bdelta_patch(
	const void  *old,     size_t  old_size,
	const void  *patch,   size_t  patch_size,
	void       **new_out, size_t *new_size_out
);

/*
 * bdelta_strerror - Return a string describing a bdelta error code.
 */
const char *bdelta_strerror(BDELTAcode code);

/*
 * bdelta_perror - Print a bdelta error message to stderr.
 *
 * This function handles @s the same way perror does.
 */
void bdelta_perror(const char *s, BDELTAcode code);

typedef struct
{
	unsigned char *cur;    /* End of string; insertion point for new bytes */
	unsigned char *end;    /* End of buffer */
	unsigned char *start;  /* Beginning of string */
} SB;

/* sb is evaluated multiple times in these macros. */
#define sb_size(sb)  ((size_t)((sb)->cur - (sb)->start))
#define sb_avail(sb) ((size_t)((sb)->end - (sb)->cur))

/* sb and need may be evaluated multiple times. */
#define sb_need(sb, need) do {           \
		if (sb_avail(sb) < (need))       \
			if (sb_grow(sb, need) != 0)  \
				goto out_of_memory;      \
	} while (0)

static int sb_init(SB *sb)
{
	sb->start = malloc(17);
	if (sb->start == NULL)
		return -1;
	sb->cur = sb->start;
	sb->end = sb->start + 16;
	return 0;
}

static int sb_grow(SB *sb, size_t need)
{
	size_t length = sb->cur - sb->start;
	size_t alloc = sb->end - sb->start;
	unsigned char *tmp;

	do {
		alloc *= 2;
	} while (alloc < length + need);

	tmp = realloc(sb->start, alloc + 1);
	if (tmp == NULL)
		return -1;
	sb->start = tmp;
	sb->cur = tmp + length;
	sb->end = tmp + alloc;
	return 0;
}

static int sb_putc(SB *sb, unsigned char c)
{
	sb_need(sb, 1);
	*sb->cur++ = c;
	return 0;

out_of_memory:
	return -1;
}

static int sb_write(SB *sb, const void *data, size_t size)
{
	sb_need(sb, size);
	memcpy(sb->cur, data, size);
	sb->cur += size;
	return 0;

out_of_memory:
	return -1;
}

static void sb_return(SB *sb, void **data_out, size_t *length_out)
{
	*sb->cur = 0;
	if (data_out)
		*data_out = sb->start;
	else
		free(sb->start);
	if (length_out)
		*length_out = sb->cur - sb->start;
}

static void sb_discard(SB *sb, void **data_out, size_t *length_out)
{
	free(sb->start);
	if (data_out)
		*data_out = NULL;
	if (length_out)
		*length_out = 0;
}

/*
 * The first byte in a patch is the "patch type", which indicates how the
 * patch is formatted.  This keeps the patch format flexible while retaining
 * backward compatibility.  Patches produced with an older version of
 * the library can be applied with a newer version.
 *
 * PT_LITERAL
 *     Contains nothing more than the content of the new text.
 *
 * PT_CSI32
 *     A string of copy, skip, and insert instructions for generating the new
 *     string from the old.
 *
 *         copy(size):   Copy @size bytes from old to new.
 *         skip(size):   Skip @size bytes of old.
 *         insert(text): Insert @text into new.
 *
 *     The syntax is as follows:
 *
 *         copy:   instruction_byte(1) size
 *         skip:   instruction_byte(2) size
 *         insert: instruction_byte(3) size $size*OCTET
 *
 *         0 <= size_param_length <= 4
 *         instruction_byte(op) = op | size_param_length << 2
 *         size: $size_param_length*OCTET
 *               -- size is an unsigned integer encoded in big endian.
 *               -- However, if size_param_length is 0, the operation size is 1.
 *
 *     Simply put, an instruction starts with an opcode and operation size.
 *     An insert instruction is followed by the bytes to be inserted.
 */
#define PT_LITERAL   10
#define PT_CSI32     11

#define OP_COPY      1
#define OP_SKIP      2
#define OP_INSERT    3

static unsigned int bytes_needed_for_size(uint32_t size)
{
	if (size == 1)
		return 0;
	else if (size <= 0xFF)
		return 1;
	else if (size <= 0xFFFF)
		return 2;
	else if (size <= 0xFFFFFF)
		return 3;
	else
		return 4;
}

/*
 * Return values:
 *
 *  BDELTA_OK:      Success
 *  BDELTA_MEMORY:  Memory allocation failed
 */
static BDELTAcode csi32_emit_op(SB *patch_out, int op, uint32_t size, const char **new_)
{
	unsigned int i;
	unsigned int size_param_length;
	size_t need;
	uint32_t tmp;

	assert(op >= 1 && op <= 3);

	if (size == 0)
		return BDELTA_OK;
	size_param_length = bytes_needed_for_size(size);

	need = 1 + size_param_length;
	if (op == OP_INSERT)
		need += size;
	sb_need(patch_out, need);

	*patch_out->cur++ = (unsigned int)op | size_param_length << 2;
	for (i = size_param_length, tmp = size; i-- > 0; tmp >>= 8)
		patch_out->cur[i] = tmp & 0xFF;
	patch_out->cur += size_param_length;

	switch (op) {
		case OP_COPY:
			*new_ += size;
			break;
		case OP_SKIP:
			break;
		case OP_INSERT:
			memcpy(patch_out->cur, *new_, size);
			patch_out->cur += size;
			*new_ += size;
			break;
		default:
			assert(0);
	}

	return BDELTA_OK;

out_of_memory:
	return BDELTA_MEMORY;
}

/*
 * On success, returns 1, advances *sp past the parsed text, and sets *op_out and *size_out.
 * On error or EOF, returns 0.
 */
static int csi32_parse_op(
	const unsigned char **sp, const unsigned char *e,
	int *op_out, uint32_t *size_out)
{
	const unsigned char *s = *sp;
	int op;
	unsigned int i;
	unsigned int size_param_length;
	uint32_t size;

	if (s >= e)
		return 0;
	op = *s & 3;
	size_param_length = *s >> 2;
	s++;
	if (op == 0 || size_param_length > 4)
		return 0;

	if (size_param_length == 0) {
		size = 1;
	} else {
		if ((size_t)(e - s) < size_param_length)
			return 0;
		size = 0;
		for (i = 0; i < size_param_length; i++) {
			size <<= 8;
			size |= *s++ & 0xFF;
		}
	}

	/* Make sure insert data fits in the patch, but don't consume it. */
	if (op == OP_INSERT && (size_t)(e - s) < size)
		return 0;

	*op_out = op;
	*size_out = size;
	*sp = s;
	return 1;
}

/*
 * bdelta uses the algorithm described in:
 *
 *     Myers, E. (1986). An O(ND) Difference Algorithm and Its Variations.
 *     Retrieved from http://www.xmailserver.org/diff2.pdf
 *
 * The pseudocode in Myers' paper (Figure 2) uses an array called V,
 * where (V[k], V[k] - k) is the endpoint of the furthest-reaching
 * D-path ending on diagonal k.
 *
 * The structure below holds the V array for every iteration of the outer loop.
 * Because each iteration produces D+1 values, a triangle is formed:
 *
 *                      k
 *        -5 -4 -3 -2 -1  0  1  2  3  4  5
 *      ----------------------------------
 *    0 |                 0                (copy 0)
 *      |                   \              skip 1
 *    1 |              0     1
 *      |                      \           skip 1, then copy 1
 *    2 |           2     2     3
 *  D   |                      /           insert 1, then copy 2
 *    3 |        3     4     5     5
 *      |                     \            skip 1, then copy 1
 *    4 |     3     4     5     7     7
 *      |                      /           insert 1
 *    5 |  3     4     5     7     -     -
 *
 * @data will literally contain: 0 0 1 2 2 3 3 4 5 5 3 4 5 7 7 3 4 5 7
 *
 * To convert this to an edit script, we first climb back to the top,
 * using the same procedure as was used when the triangle was generated:
 *
 *     If k = -D, climb right (the only way we can go).
 *     If k = +D, climb left  (the only way we can go).
 *     Otherwise, favor the greater number.
 *     If the numbers are the same, climb left.
 *
 * Finally, we convert the descent to the solution to a patch script:
 *
 *     The top number n corresponds to:
 *         copy   n
 *
 *     A descent left from a to b corresponds to:
 *         insert 1
 *         copy   b-a
 *
 *     A descent right from a to b corresponds to:
 *         skip   1
 *         copy   b-a-1
 */
typedef struct
{
	uint32_t *data;
	int solution_d;
	int solution_k;
	uint32_t *solution_ptr;
} Triangle;

/*
 * Return values:
 *
 *  BDELTA_OK:                      Success
 *  BDELTA_MEMORY:                  Memory allocation failed
 *  BDELTA_INTERNAL_DMAX_EXCEEDED:  d_max exceeded (strings are too different)
 */
static BDELTAcode build_triangle(
	const char *old,  uint32_t old_size,
	const char *new_, uint32_t new_size,
	int d_max,
	Triangle *triangle_out)
{
	int d, k;
	uint32_t x, y;
	uint32_t *data;
	uint32_t *vprev; /* position within previous row */
	uint32_t *v;     /* position within current row */
	uint32_t *vcur;  /* beginning of current row */
	size_t data_alloc = 16;

	memset(triangle_out, 0, sizeof(*triangle_out));

	data = malloc(data_alloc * sizeof(*data));
	if (data == NULL)
		return BDELTA_MEMORY;

	/* Allow dmax < 0 to mean "no limit". */
	if (d_max < 0)
		d_max = old_size + new_size;

	/*
	 * Compute the farthest-reaching 0-path so the loop after this
	 * will have a "previous" row to start with.
	 */
	for (x = 0; x < old_size && x < new_size && old[x] == new_[x]; )
		x++;
	*data = x;
	if (x >= old_size && x >= new_size) {
		/* Strings are equal, so return a triangle with one row (a dot). */
		assert(x == old_size && x == new_size);
		triangle_out->data = data;
		triangle_out->solution_d = 0;
		triangle_out->solution_k = 0;
		triangle_out->solution_ptr = data;
		return BDELTA_OK;
	}
	vprev = data;
	vcur = v = data + 1;

	/*
	 * Here is the core of the Myers diff algorithm.
	 *
	 * This is a direct translation of the pseudocode in Myers' paper,
	 * with implementation-specific adaptations:
	 *
	 *  * Every V array is preserved per iteration of the outer loop.
	 *    This is necessary so we can determine the actual patch, not just
	 *    the length of the shortest edit string.  See the coment above
	 *    the definition of Triangle for an in-depth explanation.
	 *
	 *  * Array items are stored consecutively so as to not waste space.
	 *
	 *  * The buffer holding the V arrays is expanded dynamically.
	 */
	for (d = 1; d <= d_max; d++, vprev = vcur, vcur = v) {
		/* Ensure that the buffer has enough room for this row. */
		if ((size_t)(v - data + d + 1) > data_alloc) {
			size_t vprev_idx = vprev - data;
			size_t v_idx     = v     - data;
			size_t vcur_idx  = vcur  - data;
			uint32_t *tmp;

			do {
				data_alloc *= 2;
			} while ((size_t)(v - data + d + 1) > data_alloc);

			tmp = realloc(data, data_alloc * sizeof(*data));
			if (tmp == NULL) {
				free(data);
				return BDELTA_MEMORY;
			}
			data = tmp;

			/* Relocate pointers to the buffer we just expanded. */
			vprev = data + vprev_idx;
			v     = data + v_idx;
			vcur  = data + vcur_idx;
		}

		for (k = -d; k <= d; k += 2, vprev++) {
			if (k == -d || (k != d && vprev[-1] < vprev[0]))
				x = vprev[0];
			else
				x = vprev[-1] + 1;
			y = x - k;
			while (x < old_size && y < new_size && old[x] == new_[y])
				x++, y++;
			*v++ = x;
			if (x >= old_size && y >= new_size) {
				/* Shortest edit string found. */
				assert(x == old_size && y == new_size);
				triangle_out->data = data;
				triangle_out->solution_d = d;
				triangle_out->solution_k = k;
				triangle_out->solution_ptr = v - 1;
				return BDELTA_OK;
			}
		}
	}

	free(data);
	return BDELTA_INTERNAL_DMAX_EXCEEDED;
}

/*
 * Trace a solution back to the top, returning a string of instructions
 * for descending from the top to the solution.
 *
 * An instruction is one of the following:
 *
 *  -1: Descend left.
 *  +1: Descend right.
 *   0: Finished.  You should be at the solution now.
 *
 * If memory allocation fails, this function will return NULL.
 */
static signed char *climb_triangle(const Triangle *triangle)
{
	signed char *descent;
	int d, k;
	uint32_t *p;

	assert(triangle->solution_d >= 0);

	descent = malloc(triangle->solution_d + 1);
	if (descent == NULL)
		return NULL;
	d = triangle->solution_d;
	k = triangle->solution_k;
	p = triangle->solution_ptr;
	descent[d] = 0;

	while (d > 0) {
		if (k == -d || (k != d && *(p-d-1) < *(p-d))) {
			/* Climb right */
			k++;
			p = p - d;
			descent[--d] = -1;
		} else {
			/* Climb left */
			k--;
			p = p - d - 1;
			descent[--d] = 1;
		}
	}

	return descent;
}

/*
 * Generate the actual patch, given data produced by build_triangle and
 * climb_triangle.  new_ is needed for the content of the insertions.
 *
 * See the comment above the definition of Triangle.  It concisely documents
 * how a descent down the triangle corresponds to a patch script.
 *
 * The resulting patch, including the patch type byte, is appended to patch_out.
 *
 * Return values:
 *
 *  BDELTA_OK:      Success
 *  BDELTA_MEMORY:  Memory allocation failed
 */
static BDELTAcode descent_to_patch(
	const signed char *descent,
	const Triangle *triangle,
	const char *new_, uint32_t new_size,
	SB *patch_out)
{
	const char *new_end = new_ + new_size;
	uint32_t *p = triangle->data;
	uint32_t *p2;
	int d = 0;
	int k = 0;
	int pending_op = 0;
	int current_op;
	uint32_t pending_length = 0;
	uint32_t copy_length;

	if (sb_putc(patch_out, PT_CSI32) != 0)
		return BDELTA_MEMORY;

	if (*p > 0) {
		if (csi32_emit_op(patch_out, OP_COPY, *p, &new_) != BDELTA_OK)
			return BDELTA_MEMORY;
	}

	for (; *descent != 0; descent++, p = p2) {
		if (*descent < 0) {
			/* Descend left. */
			d++;
			k--;
			p2 = p + d;
			current_op = OP_INSERT;
			assert(*p2 >= *p);
			copy_length = *p2 - *p;
		} else {
			/* Descend right. */
			d++;
			k++;
			p2 = p + d + 1;
			current_op = OP_SKIP;
			assert(*p2 > *p);
			copy_length = *p2 - *p - 1;
		}

		if (pending_op == current_op) {
			pending_length++;
		} else {
			if (pending_op != 0) {
				if (csi32_emit_op(patch_out, pending_op, pending_length, &new_) != BDELTA_OK)
					return BDELTA_MEMORY;
			}
			pending_op = current_op;
			pending_length = 1;
		}

		if (copy_length > 0) {
			if (csi32_emit_op(patch_out, pending_op, pending_length, &new_) != BDELTA_OK)
				return BDELTA_MEMORY;
			pending_op = 0;
			if (csi32_emit_op(patch_out, OP_COPY, copy_length, &new_) != BDELTA_OK)
				return BDELTA_MEMORY;
		}
	}
	assert(d == triangle->solution_d);
	assert(k == triangle->solution_k);
	assert(p == triangle->solution_ptr);

	/* Emit the last pending op, unless it's a skip. */
	if (pending_op != 0 && pending_op != OP_SKIP) {
		if (csi32_emit_op(patch_out, pending_op, pending_length, &new_) != BDELTA_OK)
			return BDELTA_MEMORY;
	}

	assert(new_ == new_end);
	return BDELTA_OK;
}

/*
 * Generate a patch using Myers' O(ND) algorithm.
 *
 * The patch is appended to @patch_out, which must be initialized before calling.
 *
 * Return values:
 *
 *  BDELTA_OK:                         Success
 *  BDELTA_MEMORY:                     Memory allocation failed
 *  BDELTA_INTERNAL_INPUTS_TOO_LARGE:  Input sizes are too large
 *  BDELTA_INTERNAL_DMAX_EXCEEDED:     d_max exceeded (strings are too different)
 */
static BDELTAcode diff_myers(
	const char *old,  size_t old_size,
	const char *new_, size_t new_size,
	SB *patch_out)
{
	Triangle triangle;
	signed char *descent;
	BDELTAcode rc;

	/* Make sure old_size + new_size does not overflow int or uint32_t. */
	if (old_size >= UINT32_MAX ||
	    new_size >= UINT32_MAX - old_size ||
	    old_size >= (unsigned int)INT_MAX ||
	    new_size >= (unsigned int)INT_MAX - old_size)
		return BDELTA_INTERNAL_INPUTS_TOO_LARGE;

	rc = build_triangle(old, old_size, new_, new_size, 1000, &triangle);
	if (rc != BDELTA_OK)
		return rc;

	descent = climb_triangle(&triangle);
	if (descent == NULL)
		goto oom1;

	if (descent_to_patch(descent, &triangle, new_, new_size, patch_out) != BDELTA_OK)
		goto oom2;

	free(descent);
	free(triangle.data);
	return BDELTA_OK;

oom2:
	free(descent);
oom1:
	free(triangle.data);
	return BDELTA_MEMORY;
}

BDELTAcode bdelta_diff(
	const void  *old,       size_t  old_size,
	const void  *new_,      size_t  new_size,
	void       **patch_out, size_t *patch_size_out)
{
	SB patch;

	if (sb_init(&patch) != 0)
		goto out_of_memory;

	if (new_size == 0)
		goto emit_new_literally;

	if (diff_myers(old, old_size, new_, new_size, &patch) != BDELTA_OK)
		goto emit_new_literally;

	if (sb_size(&patch) > new_size) {
		/*
		 * A literal copy of new is no longer than this patch.
		 * All that for nothing.
		 */
		goto emit_new_literally;
	}

	/*
	 * Verify that patch, when applied to old, produces the correct text.
	 * If it doesn't, it's a bug, but fall back to a simple emit
	 * to avert data corruption.
	 */
	{
		void *result;
		size_t result_size;
		BDELTAcode rc;
		int correct;

		rc = bdelta_patch(
			old, old_size,
			patch.start, patch.cur - patch.start,
			&result, &result_size
		);

		switch (rc) {
			case BDELTA_OK:
				correct = (result_size == new_size &&
				           memcmp(result, new_, new_size) == 0);
				free(result);
				break;

			case BDELTA_MEMORY:
				goto out_of_memory;

			default:
				correct = 0;
				break;
		}

		if (!correct) {
			assert(0);
			goto emit_new_literally;
		}
	}

	sb_return(&patch, patch_out, patch_size_out);
	return BDELTA_OK;

emit_new_literally:
	if (patch.cur != patch.start) {
		free(patch.start);
		if (sb_init(&patch) != 0)
			goto out_of_memory;
	}
	if (sb_putc(&patch, PT_LITERAL) != 0 || sb_write(&patch, new_, new_size) != 0)
		goto out_of_memory;
	sb_return(&patch, patch_out, patch_size_out);
	return BDELTA_OK;

out_of_memory:
	sb_discard(&patch, patch_out, patch_size_out);
	return BDELTA_MEMORY;
}

/*
 * Return values:
 *
 *  BDELTA_OK:              Success
 *  BDELTA_PATCH_INVALID:   Patch is malformed
 *  BDELTA_PATCH_MISMATCH:  Old string is too small
 *  BDELTA_MEMORY:          Memory allocation failed
 */
static BDELTAcode patch_csi32(
	const unsigned char *o, const unsigned char *oe,
	const unsigned char *p, const unsigned char *pe,
	SB *new_out)
{
	int op;
	uint32_t size;

	while (csi32_parse_op(&p, pe, &op, &size)) {
		if ((op == OP_COPY || op == OP_SKIP) && (size_t)(oe - o) < size) {
			/* Copy or skip instruction exceeds length of old string. */
			return BDELTA_PATCH_MISMATCH;
		}
		if (op == OP_COPY || op == OP_INSERT)
			sb_need(new_out, size);

		switch (op) {
			case OP_COPY:  /* Copy @size bytes from old string. */
				memcpy(new_out->cur, o, size);
				new_out->cur += size;
				o += size;
				break;

			case OP_SKIP:  /* Skip @size bytes of old string. */
				o += size;
				break;

			case OP_INSERT:  /* Insert @size new bytes (from the patch script). */
				memcpy(new_out->cur, p, size);
				new_out->cur += size;
				p += size;
				break;

			default:
				assert(0);
		}
	}
	if (p != pe)
		return BDELTA_PATCH_INVALID;

	return BDELTA_OK;

out_of_memory:
	return BDELTA_MEMORY;
}

BDELTAcode bdelta_patch(
	const void  *old,     size_t  old_size,
	const void  *patch,   size_t  patch_size,
	void       **new_out, size_t *new_size_out)
{
	const unsigned char *o = old;
	const unsigned char *oe = o + old_size;
	const unsigned char *p = patch;
	const unsigned char *pe = p + patch_size;
	SB result;
	BDELTAcode rc;

	if (sb_init(&result) != 0) {
		rc = BDELTA_MEMORY;
		goto discard;
	}

	if (p >= pe) {
		rc = BDELTA_PATCH_INVALID;
		goto discard;
	}

	switch (*p++) {
		case PT_LITERAL:
			if (sb_write(&result, p, pe - p) != 0) {
				rc = BDELTA_MEMORY;
				goto discard;
			}
			break;

		case PT_CSI32:
			rc = patch_csi32(o, oe, p, pe, &result);
			if (rc != BDELTA_OK)
				goto discard;
			break;

		default:
			rc = BDELTA_PATCH_INVALID;
			goto discard;
	}

	sb_return(&result, new_out, new_size_out);
	return BDELTA_OK;

discard:
	sb_discard(&result, new_out, new_size_out);
	return rc;
}

const char *bdelta_strerror(BDELTAcode code)
{
	switch (code) {
		case BDELTA_OK:
			return "Success";
		case BDELTA_MEMORY:
			return "Could not allocate memory";
		case BDELTA_PATCH_INVALID:
			return "Patch is invalid";
		case BDELTA_PATCH_MISMATCH:
			return "Patch applied to wrong data";

		case BDELTA_INTERNAL_DMAX_EXCEEDED:
			return "Difference threshold exceeded (internal error)";
		case BDELTA_INTERNAL_INPUTS_TOO_LARGE:
			return "Inputs are too large (internal error)";

		default:
			return "Invalid error code";
	}
}

void bdelta_perror(const char *s, BDELTAcode code)
{
	if (s != NULL && *s != '\0')
		fprintf(stderr, "%s: %s\n", s, bdelta_strerror(code));
	else
		fprintf(stderr, "%s\n", bdelta_strerror(code));
}

static int test_trivial(const char *old, const char *new_)
{
	void *patch;
	size_t patch_size;
	BDELTAcode rc;

	void *new2;
	size_t new2_size;

	rc = bdelta_diff(old, strlen(old), new_, strlen(new_), &patch, &patch_size);
	if (rc != BDELTA_OK) {
		bdelta_perror("bdelta_diff", rc);
		return 0;
	}

	if (patch_size > strlen(new_) + 1) {
		fprintf(stderr, "bdelta_diff produced a patch larger than a simple literal emitting the new string.\n");
		return 0;
	}

	rc = bdelta_patch(old, strlen(old), patch, patch_size, &new2, &new2_size);
	if (rc != BDELTA_OK) {
		bdelta_perror("bdelta_patch", rc);
		return 0;
	}

    printf("\"%s\"\n", new2);

    return 1;
}

int main(void)
{
	test_trivial("abcabba", "cbabac"); // CHECK: "cbabac"
	test_trivial("aaabbbcdaabcc", "aaabbcdaabeca"); // CHECK: "aaabbcdaabeca"
	test_trivial("aaaaaaaa", "bbbbbbbb");   // CHECK: "bbbbbbbb"
	test_trivial("aaaaaaaa", ""); // CHECK: ""
	test_trivial("", "bbbbbbbb"); // CHECK: "bbbbbbbb"
	test_trivial("", ""); // CHECK: ""
	test_trivial("aaaaaaaa", "aaaaaaaabbbbbbbb"); // CHECK: "aaaaaaaabbbbbbbb"
	test_trivial("aaaaaaaa", "bbbbbbbbaaaaaaaa"); // CHECK: "bbbbbbbbaaaaaaaa"
	test_trivial("aaaaaaaabbbbbbbb", "aaaaaaaa"); // CHECK: "aaaaaaaa"
	test_trivial("aaaaaaaabbbbbbbb", "bbbbbbbb"); // CHECK: "bbbbbbbb"
	test_trivial("aaaaaaaabbbbbbbb", "bbbbbbbb"); // CHECK: "bbbbbbbb"
	test_trivial("abababababababab", "babababababababa"); // CHECK: "babababababababa"
	test_trivial("aababcabcdabcde", "aababcabcdabcde"); // CHECK: "aababcabcdabcde"

	return 0;
}
