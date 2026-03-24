import Testing
import Dispatch
@testable import SeismoscopeKit

@Test func appendAndRetrieve() {
    let buffer = CircularBuffer<Int>(capacity: 10, defaultValue: 0)
    for i in 0..<5 {
        buffer.append(i)
    }
    let result = buffer.last(5)
    #expect(result == [0, 1, 2, 3, 4])
    #expect(buffer.count == 5)
}

@Test func overwriteOldest() {
    let buffer = CircularBuffer<Int>(capacity: 10, defaultValue: 0)
    for i in 0..<15 {
        buffer.append(i)
    }
    let result = buffer.last(10)
    #expect(result == [5, 6, 7, 8, 9, 10, 11, 12, 13, 14])
    #expect(buffer.count == 10)
    #expect(buffer.isFull == true)
}

@Test func lastMoreThanCount() {
    let buffer = CircularBuffer<Int>(capacity: 10, defaultValue: 0)
    for i in 0..<5 {
        buffer.append(i)
    }
    let result = buffer.last(20)
    #expect(result.count == 5)
}

@Test func countIncrementsToCapacity() {
    let buffer = CircularBuffer<Int>(capacity: 5, defaultValue: 0)
    #expect(buffer.count == 0)
    #expect(buffer.isFull == false)
    buffer.append(1)
    buffer.append(2)
    buffer.append(3)
    #expect(buffer.count == 3)
    #expect(buffer.isFull == false)
    buffer.append(4)
    buffer.append(5)
    #expect(buffer.count == 5)
    #expect(buffer.isFull == true)
}

@Test func concurrentReadWrite() {
    let buffer = CircularBuffer<Int>(capacity: 100, defaultValue: 0)
    for _ in 0..<100 {
        DispatchQueue.concurrentPerform(iterations: 6) { index in
            if index < 4 {
                // 4 writers, 2500 appends each
                for i in 0..<2500 {
                    buffer.append(i)
                }
            } else {
                // 2 readers
                for _ in 0..<2500 {
                    _ = buffer.last(100)
                }
            }
        }
    }
    #expect(buffer.count == buffer.capacity)
    #expect(buffer.isFull == true)
}
