/// Open Source Initiative OSI - The MIT License (MIT):Licensing
/// The MIT License (MIT)
/// Copyright (c) 2024 Ralph Caraveo (deckarep@gmail.com)
/// Permission is hereby granted, free of charge, to any person obtaining a copy of
/// this software and associated documentation files (the "Software"), to deal in
/// the Software without restriction, including without limitation the rights to
/// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
/// of the Software, and to permit persons to whom the Software is furnished to do
/// so, subject to the following conditions:
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.
///
///
const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

/// TODO: support Zig "strings" eventually, doesn't work currently.
/// fn Set(E) creates a set based on element type E.
/// This implementation is backed by the std.AutoHashMap implementation
/// where a Value is not needed and considered to be void and
/// a Key is considered to be a Set element of type E.
/// The Set comes complete with the common set operations expected
/// in a comprehensive set-based data-structure.
pub fn Set(comptime E: type) type {
    return struct {
        // NOTE: instead of the extra 16 bytes to keep this around
        // just piggyback off of the internal map allocator this way
        // the Set type isn't larger than it needs to be.
        // See "sizeOf" test-case below.

        // allocator: std.mem.Allocator,

        map: Map,

        /// The type of the internal hash map
        pub const Map = std.AutoHashMap(E, void);
        /// The integer type used to store the size of the map, borrowed from map
        pub const Size = Map.Size;
        /// The iterator type returned by iterator(), key-only for sets
        pub const Iterator = Map.KeyIterator;

        const Self = @This();

        /// Initialzies a Set with the given Allocator
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .map = std.AutoHashMap(E, void).init(allocator),
            };
        }

        /// Initialzies a Set using a capacity hint, with the given Allocator
        pub fn initCapacity(allocator: Allocator, num: Size) Allocator.Error!Self {
            var self = Self.init(allocator);
            try self.map.ensureTotalCapacity(num);
            return self;
        }

        /// Destory the Set
        pub fn deinit(self: *Self) void {
            self.map.deinit();
            self.* = undefined;
        }

        /// Adds a single element to the set and an allocation may occur.
        /// add may return an Allocator.Error or bool indicating if the element
        /// was actually added if not already known.
        pub fn add(self: *Self, element: E) Allocator.Error!bool {
            const prevCount = self.map.count();
            try self.map.put(element, {});
            return prevCount != self.map.count();
        }

        /// Appends all elements from the provided set, and may allocate.
        /// append returns an Allocator.Error or Size which represents how
        /// many elements added and not previously in the Set.
        pub fn append(self: *Self, other: Self) Allocator.Error!Size {
            const prevCount = self.map.count();

            try self.unionUpdate(other);
            return self.map.count() - prevCount;
        }

        /// Appends all elements from the provided slice, and may allocate.
        /// appendSlice returns an Allocator.Error or Size which represents how
        /// many elements added and not previously in the slice.
        pub fn appendSlice(self: *Self, elements: []const E) Allocator.Error!Size {
            const prevCount = self.map.count();
            for (elements) |el| {
                try self.map.put(el, {});
            }
            return self.map.count() - prevCount;
        }

        /// Returns the number of total elements which may be present before
        /// it is no longer guaranteed that no allocations will be performed.
        pub fn capacity(self: *Self) Size {
            // Note: map.capacity() requires mutable access, probably an oversight.
            return self.map.capacity();
        }

        /// Cardinality effectively returns the size of the set
        pub fn cardinality(self: Self) Size {
            return self.map.count();
        }

        /// Invalidates all element pointers.
        pub fn clearAndFree(self: *Self) void {
            self.map.clearAndFree();
        }

        /// Invalidates all element pointers.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.map.clearRetainingCapacity();
        }

        /// Creates a copy of this set, using the same allocator.
        /// clone may return an Allocator.Error or the cloned Set.
        pub fn clone(self: *Self) Allocator.Error!Self {
            // Take a stack copy of self.
            var cloneSelf = self.*;
            // Clone the interal map.
            cloneSelf.map = try self.map.clone();
            return cloneSelf;
        }

        /// Creates a copy of this set, using a specified allocator.
        /// cloneWithAllocator may be return an Allocator.Error or the cloned Set.
        pub fn cloneWithAllocator(self: *Self, allocator: Allocator) Allocator.Error!Self {
            // Since we're borrowing the internal map allocator, temporarily back it up.
            const prevAllocator = self.map.allocator;
            // Restore it at the end of the func, because the self.map should use the
            // original allocator.
            defer self.map.allocator = prevAllocator;

            // The cloned map must use and refer to the new allocator only.
            self.map.allocator = allocator;
            const cloneSelf = try self.clone();
            return cloneSelf;
        }

        /// Returns true when the provided element exists within the Set otherwise false.
        pub fn contains(self: Self, element: E) bool {
            return self.map.contains(element);
        }

        /// Returns true when all elements in the provided slice are present otherwise false.
        pub fn containsAll(self: Self, other: Self) bool {
            var iter = other.iterator();
            while (iter.next()) |el| {
                if (!self.map.contains(el.*)) {
                    return false;
                }
            }
            return true;
        }

        /// Returns true when all elements in the provided slice are present otherwise false.
        pub fn containsAllSlice(self: Self, elements: []const E) bool {
            for (elements) |el| {
                if (!self.map.contains(el)) {
                    return false;
                }
            }
            return true;
        }

        /// Returns true when at least one or more elements exist within the Set otherwise false.
        pub fn containsAny(self: Self, other: Self) bool {
            var iter = other.iterator();
            while (iter.next()) |el| {
                if (self.map.contains(el.*)) {
                    return true;
                }
            }
            return false;
        }

        /// Returns true when at least one or more elements exist within the Set otherwise false.
        pub fn containsAnySlice(self: Self, elements: []const E) bool {
            for (elements) |el| {
                if (self.map.contains(el)) {
                    return true;
                }
            }
            return false;
        }

        /// differenceOf returns the difference between this set
        /// and other. The returned set will contain
        /// all elements of this set that are not also
        /// elements of the other.
        ///
        /// Caller owns the newly allocated/returned set.
        pub fn differenceOf(self: Self, other: Self) Allocator.Error!Self {
            var diffSet = Self.init(self.map.allocator);

            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                if (!other.map.contains(entry.key_ptr.*)) {
                    _ = try diffSet.add(entry.key_ptr.*);
                }
            }
            return diffSet;
        }

        /// differenceUpdate does an in-place mutation of this set
        /// and other. This set will contain all elements of this set that are not
        /// also elements of other.
        pub fn differenceUpdate(self: *Self, other: Self) Allocator.Error!void {
            // In-place mutation invalidates iterators therefore a temp set is needed.
            // So instead of a temp set, just invoke the regular full function which
            // allocates and returns a set then swap out the map internally.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const diffSet = try self.differenceOf(other);

            // Destroy the internal map.
            self.map.deinit();

            // Swap it out with the new set.
            self.map = diffSet.map;
        }

        fn dump(self: Self) void {
            std.log.err("\ncardinality: {d}\n", .{self.cardinality()});
            var iter = self.iterator();
            while (iter.next()) |el| {
                std.log.err("  element: {d}\n", .{el.*});
            }
        }

        /// Increases capacity, guaranteeing that insertions up until the
        /// `expected_count` will not cause an allocation, and therefore cannot fail.
        pub fn ensureTotalCapacity(self: *Self, expected_count: Size) Allocator.Error!void {
            return self.map.ensureTotalCapacity(expected_count);
        }

        /// Increases capacity, guaranteeing that insertions up until
        /// `additional_count` **more** items will not cause an allocation, and
        /// therefore cannot fail.
        pub fn ensureUnusedCapacity(self: *Self, additional_count: Size) Allocator.Error!void {
            return self.map.ensureUnusedCapacity(additional_count);
        }

        /// eql determines if two sets are equal to each
        /// other. If they have the same cardinality
        /// and contain the same elements, they are
        /// considered equal. The order in which
        /// the elements were added is irrelevant.
        pub fn eql(self: Self, other: Self) bool {
            // First discriminate on cardinalities of both sets.
            if (self.map.count() != other.map.count()) {
                return false;
            }

            // Now check for each element one for one and exit early
            // on the first non-match.
            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                if (!other.map.contains(entry.key_ptr.*)) {
                    return false;
                }
            }

            return true;
        }

        /// intersectionOf returns a new set containing only the elements
        /// that exist only in both sets.
        ///
        /// Caller owns the newly allocated/returned set.
        pub fn intersectionOf(self: Self, other: Self) Allocator.Error!Self {
            var interSet = Self.init(self.map.allocator);

            // Optimization: iterate over whichever set is smaller.
            // Matters when disparity in cardinality is large.
            var s = other;
            var o = self;
            if (self.map.count() < other.map.count()) {
                s = self;
                o = other;
            }

            var iter = s.map.iterator();
            while (iter.next()) |entry| {
                if (o.map.contains(entry.key_ptr.*)) {
                    _ = try interSet.add(entry.key_ptr.*);
                }
            }

            return interSet;
        }

        /// intersectionUpdate does an in-place intersecting update
        /// to the current set from the other set keeping only
        /// elements found in this Set and the other Set.
        pub fn intersectionUpdate(self: *Self, other: Self) Allocator.Error!void {
            // In-place mutation invalidates iterators therefore a temp set is needed.
            // So instead of a temp set, just invoke the regular full function which
            // allocates and returns a set then swap out the map internally.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const interSet = try self.intersectionOf(other);

            // Destroy the internal map.
            self.map.deinit();

            // Swap it out with the new set.
            self.map = interSet.map;
        }

        /// In place style:
        /// differenceOfUpdate
        /// symmetric_differenceOf_update
        /// Returns true if the set is empty otherwise false
        pub fn isEmpty(self: Self) bool {
            return self.map.count() == 0;
        }

        /// Create an iterator over the elements in the set.
        /// The iterator is invalidated if the set is modified during iteration.
        pub fn iterator(self: Self) Iterator {
            return self.map.keyIterator();
        }

        /// properSubsetOf determines if every element in this set is in
        /// the other set but the two sets are not equal.
        pub fn properSubsetOf(self: Self, other: Self) bool {
            return self.map.count() < other.map.count() and self.subsetOf(other);
        }

        /// properSupersetOf determines if every element in the other set
        /// is in this set but the two sets are not equal.
        pub fn properSupersetOf(self: Self, other: Self) bool {
            return self.map.count() > other.map.count() and self.supersetOf(other);
        }

        /// subsetOf determines if every element in this set is in
        /// the other set.
        pub fn subsetOf(self: Self, other: Self) bool {
            // First discriminate on cardinalties of both sets.
            if (self.map.count() > other.map.count()) {
                return false;
            }

            // Now check that self set has at least some elements from other.
            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                if (!other.map.contains(entry.key_ptr.*)) {
                    return false;
                }
            }

            return true;
        }

        /// subsetOf determines if every element in the other Set is in
        /// the this Set.
        pub fn supersetOf(self: Self, other: Self) bool {
            // This is just the converse of subsetOf.
            return other.subsetOf(self);
        }

        /// pop removes and returns an arbitrary ?E from the set.
        /// Order is not guaranteed.
        /// This safely returns null if the Set is empty.
        pub fn pop(self: *Self) ?E {
            if (self.map.count() > 0) {
                var iter = self.map.iterator();
                // NOTE: No in-place mutation as it invalidates live iterators.
                // So a temporary capture is taken.
                var capturedElement: E = undefined;
                while (iter.next()) |entry| {
                    capturedElement = entry.key_ptr.*;
                    break;
                }
                _ = self.map.remove(capturedElement);
                return capturedElement;
            } else {
                return null;
            }
        }

        /// remove discards a single element from the Set
        pub fn remove(self: *Self, element: E) bool {
            return self.map.remove(element);
        }

        /// removesAll discards all elements passed as a slice from the Set
        pub fn removeAll(self: *Self, elements: []const E) void {
            for (elements) |el| {
                _ = self.map.remove(el);
            }
        }

        /// symmetricDifferenceOf returns a new set with all elements which are
        /// in either this set or the other set but not in both.
        ///
        /// The caller owns the newly allocated/returned Set.
        pub fn symmetricDifferenceOf(self: Self, other: Self) Allocator.Error!Self {
            var sdSet = Self.init(self.map.allocator);

            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                if (!other.map.contains(entry.key_ptr.*)) {
                    _ = try sdSet.add(entry.key_ptr.*);
                }
            }

            iter = other.map.iterator();
            while (iter.next()) |entry| {
                if (!self.map.contains(entry.key_ptr.*)) {
                    _ = try sdSet.add(entry.key_ptr.*);
                }
            }

            return sdSet;
        }

        /// symmetricDifferenceUpdate does an in-place mutation with all elements
        /// which are in either this set or the other set but not in both.
        pub fn symmetricDifferenceUpdate(self: *Self, other: Self) Allocator.Error!void {
            // In-place mutation invalidates iterators therefore a temp set is needed.
            // So instead of a temp set, just invoke the regular full function which
            // allocates and returns a set then swap out the map internally.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const sd = try self.symmetricDifferenceOf(other);

            // Destroy the internal map.
            self.map.deinit();

            // Swap it out with the new set.
            self.map = sd.map;
        }

        /// union returns a new set with all elements in both sets.
        ///
        /// The caller owns the newly allocated/returned Set.
        pub fn unionOf(self: Self, other: Self) Allocator.Error!Self {
            // Sniff out larger set for capacity hint.
            var n = self.map.count();
            if (other.map.count() > n) n = other.map.count();

            var uSet = try Self.initCapacity(
                self.map.allocator,
                @intCast(n),
            );

            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                _ = try uSet.add(entry.key_ptr.*);
            }

            iter = other.map.iterator();
            while (iter.next()) |entry| {
                _ = try uSet.add(entry.key_ptr.*);
            }

            return uSet;
        }

        /// unionUpdate does an in-place union of the current Set and other Set.
        ///
        /// Allocations may occur.
        pub fn unionUpdate(self: *Self, other: Self) Allocator.Error!void {
            var iter = other.map.iterator();
            while (iter.next()) |entry| {
                _ = try self.add(entry.key_ptr.*);
            }
        }
    };
}

const testing = std.testing;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "example usage" {
    // import the namespace.
    // const set = @import("set.zig");

    // Create a set of u32s called A
    var A = Set(u32).init(std.testing.allocator);
    defer A.deinit();

    // Add some data
    _ = try A.add(5);
    _ = try A.add(6);
    _ = try A.add(7);

    // Add more data; single shot, duplicate data is ignored.
    _ = try A.appendSlice(&.{ 5, 3, 0, 9 });

    // Create another set called B
    var B = Set(u32).init(std.testing.allocator);
    defer B.deinit();

    // Add data to B
    _ = try B.appendSlice(&.{ 50, 30, 20 });

    // Get the union of A | B
    var un = try A.unionOf(B);
    defer un.deinit();

    // Grab an iterator and dump the contents.
    var iter = un.iterator();
    while (iter.next()) |el| {
        std.log.debug("element: {d}", .{el.*});
    }
}

test "comprehensive usage" {
    var set = Set(u32).init(std.testing.allocator);
    defer set.deinit();

    try expect(set.isEmpty());

    _ = try set.add(8);
    _ = try set.add(6);
    _ = try set.add(7);
    try expectEqual(set.cardinality(), 3);

    _ = try set.appendSlice(&.{ 5, 3, 0, 9 });

    // Positive cases.
    try expect(set.contains(8));
    try expect(set.containsAllSlice(&.{ 5, 3, 9 }));
    try expect(set.containsAnySlice(&.{ 5, 55, 12 }));

    // Negative cases.
    try expect(!set.contains(99));
    try expect(!set.containsAllSlice(&.{ 8, 6, 77 }));
    try expect(!set.containsAnySlice(&.{ 99, 55, 44 }));

    try expectEqual(set.cardinality(), 7);

    var other = Set(u32).init(std.testing.allocator);
    defer other.deinit();

    try expect(other.isEmpty());

    _ = try other.add(8);
    _ = try other.add(6);
    _ = try other.add(7);

    _ = try other.appendSlice(&.{ 5, 3, 0, 9 });

    try expect(set.eql(other));
    try expectEqual(other.cardinality(), 7);

    try expect(other.remove(8));
    try expectEqual(other.cardinality(), 6);
    try expect(!other.remove(55));
    try expect(!set.eql(other));

    other.removeAll(&.{ 6, 7 });
    try expectEqual(other.cardinality(), 4);

    // intersectionOf
    var inter = try set.intersectionOf(other);
    defer inter.deinit();
    try expect(!inter.isEmpty());
    try expectEqual(inter.cardinality(), 4);
    try expect(inter.containsAllSlice(&.{ 5, 3, 0, 9 }));

    // Union
    var un = try set.unionOf(other);
    defer un.deinit();
    try expect(!un.isEmpty());
    try expectEqual(un.cardinality(), 7);
    try expect(un.containsAllSlice(&.{ 8, 6, 7, 5, 3, 0, 9 }));

    // differenceOf
    var diff = try set.differenceOf(other);
    defer diff.deinit();
    try expect(!diff.isEmpty());
    try expectEqual(diff.cardinality(), 3);
    try expect(diff.containsAllSlice(&.{ 8, 7, 6 }));

    // symmetricDifferenceOf
    _ = try set.add(11111);
    _ = try set.add(9999);
    _ = try other.add(7777);
    var symmDiff = try set.symmetricDifferenceOf(other);
    defer symmDiff.deinit();
    try expect(!symmDiff.isEmpty());
    try expectEqual(symmDiff.cardinality(), 6);
    try expect(symmDiff.containsAllSlice(&.{ 7777, 11111, 8, 7, 6, 9999 }));

    // subsetOf

    // supersetOf
}

test "clear/capacity" {
    var a = Set(u32).init(std.testing.allocator);
    defer a.deinit();

    try expectEqual(0, a.cardinality());
    try expectEqual(0, a.capacity());

    const cap = 99;
    var b = try Set(u32).initCapacity(std.testing.allocator, cap);
    defer b.deinit();

    try expectEqual(0, b.cardinality());
    try expect(b.capacity() >= cap);

    for (0..cap) |val| {
        _ = try b.add(@intCast(val));
    }

    try expectEqual(99, b.cardinality());
    try expect(b.capacity() >= cap);

    b.clearRetainingCapacity();

    try expectEqual(0, b.cardinality());
    try expect(b.capacity() >= cap);

    b.clearAndFree();

    try expectEqual(0, b.cardinality());
    try expectEqual(b.capacity(), 0);
}

test "clone" {
    {
        // clone
        var a = Set(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 20, 30, 40 });

        var b = try a.clone();
        defer b.deinit();

        try expect(a.eql(b));
    }

    {
        // cloneWithAllocator
        var a = Set(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 20, 30, 40 });

        // Use a different allocator than the test one.
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const tmpAlloc = gpa.allocator();
        defer {
            const deinit_status = gpa.deinit();
            // Fail test; can't try in defer as defer is executed after we return
            if (deinit_status == .leak) expect(false) catch @panic("TEST FAIL");
        }

        var b = try a.cloneWithAllocator(tmpAlloc);
        defer b.deinit();

        try expect(a.map.allocator.ptr != b.map.allocator.ptr);
        try expect(a.eql(b));
    }
}

test "pop" {
    var a = Set(u32).init(std.testing.allocator);
    defer a.deinit();
    _ = try a.appendSlice(&.{ 20, 30, 40 });

    // No assumptions can be made about pop order.
    while (a.pop()) |result| {
        try expect(result == 20 or result == 30 or result == 40);
    }

    // At this point, set must be empty.
    try expectEqual(a.cardinality(), 0);
    try expect(a.isEmpty());

    // Lastly, pop should safely return null.
    try expect(a.pop() == null);
}

test "subset/superset" {
    {
        // subsetOf
        var a = Set(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 1, 2, 3, 5, 7 });

        var b = Set(u32).init(std.testing.allocator);
        defer b.deinit();

        // b should be a subset of a.
        try expect(b.subsetOf(a));

        _ = try b.add(72);

        // b should not be a subset of a, because 72 is not in a.
        try expect(!b.subsetOf(a));
    }

    {
        // supersetOf
        var a = Set(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 9, 5, 2, 1, 11 });

        var b = Set(u32).init(std.testing.allocator);
        defer b.deinit();
        _ = try b.appendSlice(&.{ 5, 2, 11 });

        // set a should be a superset of set b
        try expect(!b.supersetOf(a));

        _ = try b.add(42);

        // TODO: figure out why this fails.
        //set a should not be a superset of set b because b has 42
        // try expect(a.supersetOf(&b));
    }
}

test "iterator" {
    var a = Set(u32).init(std.testing.allocator);
    defer a.deinit();
    _ = try a.appendSlice(&.{ 20, 30, 40 });

    var sum: u32 = 0;
    var iterCount: usize = 0;
    var iter = a.iterator();
    while (iter.next()) |el| {
        sum += el.*;
        iterCount += 1;
    }

    try expectEqual(90, sum);
    try expectEqual(3, iterCount);
}

test "in-place methods" {
    // intersectionUpdate
    var a = Set(u32).init(std.testing.allocator);
    defer a.deinit();
    _ = try a.appendSlice(&.{ 10, 20, 30, 40 });

    var b = Set(u32).init(std.testing.allocator);
    defer b.deinit();
    _ = try b.appendSlice(&.{ 44, 20, 30, 66 });

    try a.intersectionUpdate(b);
    try expectEqual(a.cardinality(), 2);
    try expect(a.containsAllSlice(&.{ 20, 30 }));

    // unionUpdate
    var c = Set(u32).init(std.testing.allocator);
    defer c.deinit();
    _ = try c.appendSlice(&.{ 10, 20, 30, 40 });

    var d = Set(u32).init(std.testing.allocator);
    defer d.deinit();
    _ = try d.appendSlice(&.{ 44, 20, 30, 66 });

    try c.unionUpdate(d);
    try expectEqual(c.cardinality(), 6);
    try expect(c.containsAllSlice(&.{ 10, 20, 30, 40, 66 }));

    // differenceUpdate
    var e = Set(u32).init(std.testing.allocator);
    defer e.deinit();
    _ = try e.appendSlice(&.{ 1, 11, 111, 1111, 11111 });

    var f = Set(u32).init(std.testing.allocator);
    defer f.deinit();
    _ = try f.appendSlice(&.{ 1, 11, 111, 222, 2222, 1111 });

    try e.differenceUpdate(f);

    try expectEqual(1, e.cardinality());
    try expect(e.contains(11111));

    // symmetricDifferenceUpdate
    var g = Set(u32).init(std.testing.allocator);
    defer g.deinit();
    _ = try g.appendSlice(&.{ 2, 22, 222, 2222, 22222 });

    var h = Set(u32).init(std.testing.allocator);
    defer h.deinit();
    _ = try h.appendSlice(&.{ 1, 11, 111, 333, 3333, 2222, 1111 });

    try g.symmetricDifferenceUpdate(h);

    try expectEqual(10, g.cardinality());
    try expect(g.containsAllSlice(&.{ 1, 2, 11, 111, 22, 222, 1111, 333, 3333, 22222 }));
}

test "sizeOf" {
    // Instead of the Set having it's own allocator it just borrows the internal map.
    // This is to keep the object size the same as the AudoHashMap.
    const expectedByteSize = 40;
    try expectEqual(expectedByteSize, @sizeOf(std.hash_map.AutoHashMap(u32, void)));
    try expectEqual(expectedByteSize, @sizeOf(Set(u32)));
}
