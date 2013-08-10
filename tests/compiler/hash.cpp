// 
// Copyright 2013 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

#include "output.h"

#define NUM_BUCKETS 64

struct HashNode
{
	HashNode *next;
	int value;
	char key[1];
};

HashNode *hashBuckets[NUM_BUCKETS];
char *allocNext = (char*) 0x10000;

int strcmp(const char *str1, const char *str2)
{
	while (*str1) {
		if (*str2 == 0)
			return -1;

		if (*str1 != *str2)
			return *str1 - *str2;

		str1++;
		str2++;
	}

	if (*str2)
		return 1;

	return 0;
}

unsigned long strlen(const char *str)
{
	long len = 0;
	while (*str++)
		len++;

	return len;
}

char* strcpy(char *dest, const char *src)
{
	char *d = dest;
	while (*src)
		*d++ = *src++;

	*d = 0;
	return dest;
}

int hashString(const char *str)
{
	unsigned int hash = 1;
	
	for (const char *c = str; *c; c++)
		hash = (hash << 7) ^ (hash >> 24) ^ *c;

	return hash & 0x7fffffff;
}

static HashNode *getHashNode(const char *string)
{
	int bucket = (hashString(string) * 7) & (NUM_BUCKETS - 1);
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
		node = (HashNode*) allocNext;
		allocNext += sizeof(HashNode) + strlen(string);
		strcpy(node->key, string);
		int bucket = (hashString(string) * 7) & (NUM_BUCKETS - 1);
		node->next = hashBuckets[bucket];
		hashBuckets[bucket] = node;
	}

	node->value = value;
}

Output output;

void testKey(const char *key)
{
	HashNode *node = getHashNode(key);
	if (node == 0)
		output << key << " NOT FOUND\n";
	else
		output << node->key << ":" << node->value << "\n";
}

int main()
{
	insertHash("foo", 12);
	insertHash("bar", 14);
	insertHash("baz", 27);
	insertHash("bar", 96);	// Replaces previous value of bar

	testKey("foo"); // CHECK: foo:0x0000000c
	testKey("bit"); // CHECK: bit NOT FOUND
	testKey("bar"); // CHECK: bar:0x00000060
	testKey("baz"); // CHECK: baz:0x0000001b

	return 0;
}
