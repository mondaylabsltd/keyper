import { describe, expect, it } from 'vitest';
import { en, zh } from './content';

/** The shape of a value: every key and every list length, without the words. */
function shape(value: unknown): unknown {
	if (Array.isArray(value)) return value.map(shape);
	if (value && typeof value === 'object') {
		return Object.fromEntries(Object.entries(value).map(([key, inner]) => [key, shape(inner)]));
	}
	return typeof value;
}

describe('content', () => {
	it('says the same things in both languages', () => {
		expect(shape(zh)).toEqual(shape(en));
	});

	it('links each language to the other', () => {
		expect(en.other.path).toBe(zh.path);
		expect(zh.other.path).toBe(en.path);
	});
});
