// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 

#include <stdio.h>
#include <string.h>

#define NUM_BUCKETS 17

struct HashNode
{
	HashNode *next;
	int value;
	char key[1];
};

HashNode *hashBuckets[NUM_BUCKETS];

int hashString(const char *str)
{
	unsigned int hash = 1;
	
	for (const char *c = str; *c; c++)
		hash = (hash << 7) ^ (hash >> 24) ^ *c;

	return hash & 0x7fffffff;
}

static HashNode *getHashNode(const char *string)
{
	int bucket = hashString(string) % NUM_BUCKETS;
	for (HashNode *node = hashBuckets[bucket]; node; node = node->next)
		if (strcmp(string, node->key) == 0)
			return node;

	return 0;
}

void insertHash(const char *string, int value)
{
	HashNode *node = getHashNode(string);
	if (!node)
	{
		node = new HashNode;
		strcpy(node->key, string);
		int bucket = hashString(string) % NUM_BUCKETS;
		node->next = hashBuckets[bucket];
		hashBuckets[bucket] = node;
	}

	node->value = value;
}

void testKey(const char *key)
{
	HashNode *node = getHashNode(key);
	if (node == 0)
		printf("%s NOT FOUND\n", key);
	else
		printf("%s=%d\n", node->key, node->value);
}

int main()
{
	insertHash("foo", 12);
	insertHash("bar", 14);
	insertHash("baz", 27);
	insertHash("bar", 96);	// Replaces previous value of bar

	testKey("foo"); // CHECK: foo=12
	testKey("bit"); // CHECK: bit NOT FOUND
	testKey("bar"); // CHECK: bar=96
	testKey("baz"); // CHECK: baz=27

	return 0;
}
