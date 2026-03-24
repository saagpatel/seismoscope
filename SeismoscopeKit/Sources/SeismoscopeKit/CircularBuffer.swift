import Foundation

/// A thread-safe, fixed-capacity circular buffer that overwrites the oldest
/// element when full. All operations are O(1) except `last(_:)` which is O(n).
public final class CircularBuffer<T: Sendable>: @unchecked Sendable {

    private var storage: [T]
    private var head: Int = 0
    private var _count: Int = 0
    public let capacity: Int
    private let lock = NSLock()

    public init(capacity: Int, defaultValue: T) {
        precondition(capacity > 0, "CircularBuffer capacity must be > 0")
        self.capacity = capacity
        self.storage = [T](repeating: defaultValue, count: capacity)
    }

    /// Append an element. O(1). Overwrites the oldest element when the buffer is full.
    public func append(_ element: T) {
        lock.lock()
        defer { lock.unlock() }
        storage[head] = element
        head = (head + 1) % capacity
        _count = min(_count + 1, capacity)
    }

    /// Return the most recent `n` elements in chronological order. O(n).
    /// If `n` exceeds the current fill, all available elements are returned.
    public func last(_ n: Int) -> [T] {
        lock.lock()
        defer { lock.unlock() }
        let n = min(n, _count)
        guard n > 0 else { return [] }
        let start = (head - n + capacity) % capacity
        var result = [T]()
        result.reserveCapacity(n)
        for i in 0..<n {
            result.append(storage[(start + i) % capacity])
        }
        return result
    }

    /// The number of elements currently stored.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    /// Whether the buffer has reached its capacity.
    public var isFull: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _count == capacity
    }
}
