/**
 * Sample test file to demonstrate Jest testing
 * Replace or expand these tests with your actual application tests
 */

describe('Sample Tests', () => {
  test('basic arithmetic works', () => {
    expect(1 + 1).toBe(2);
  });

  test('string concatenation works', () => {
    const greeting = 'Hello' + ' ' + 'World';
    expect(greeting).toBe('Hello World');
  });

  test('array operations work', () => {
    const numbers = [1, 2, 3, 4, 5];
    expect(numbers.length).toBe(5);
    expect(numbers[0]).toBe(1);
  });
});
