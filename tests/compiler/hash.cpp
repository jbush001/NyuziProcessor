// 
// Copyright 2011-2015 Jeff Bush
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
