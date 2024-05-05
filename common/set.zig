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
        allocator: std.mem.Allocator,
        map: Map,

        const Self = @This();
        pub const Map = std.AutoHashMap(E, void);
        pub const Size = Map.Size;
        /// The iterator type returned by iterator()
        pub const Iterator = Map.KeyIterator;

        /// Initialzies a Set with the given std.mem.Allocator
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .map = std.AutoHashMap(E, void).init(allocator),
                .allocator = allocator,
            };
        }

        /// Initialzies a Set using a capacity hint, with the given std.mem.Allocator
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

        /// Add adds a single element to the set and an allocation may occur
        pub fn add(self: *Self, element: E) Allocator.Error!bool {
            const prevCount = self.map.count();
            try self.map.put(element, {});
            return prevCount != self.map.count();
        }

        /// Appends all elements from the provided slice, and may allocate
        pub fn appendSlice(self: *Self, elements: []const E) Allocator.Error!Size {
            const prevCount = self.map.count();
            for (elements) |el| {
                try self.map.put(el, {});
            }
            return self.map.count() - prevCount;
        }

        /// Cardinality effectively returns the size of the set
        pub fn cardinality(self: *const Self) Size {
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

        /// Creates a copy of this set, using the same allocator
        pub fn clone(self: *const Self) Allocator.Error!Self {
            // Take a stack copy of self.
            var cloneSelf = self.*;
            cloneSelf.map = try self.map.clone();
            return cloneSelf;
        }

        /// Creates a copy of this set, using a specified allocator
        pub fn cloneWithAllocator(self: *const Self, allocator: Allocator) Allocator.Error!Self {
            var cloneSelf = try self.clone();
            cloneSelf.allocator = allocator;
            return cloneSelf;
        }

        /// Returns true when all elements in the provided slice are present otherwise false.
        pub fn containsAll(self: *const Self, elements: []const E) bool {
            for (elements) |el| {
                if (!self.map.contains(el)) {
                    return false;
                }
            }
            return true;
        }

        /// Returns true when the provided element exists within the Set otherwise false.
        pub fn containsOne(self: *const Self, element: E) bool {
            return self.map.contains(element);
        }

        /// Returns true when at least one or more elements exist within the Set otherwise false.
        pub fn containsAny(self: *const Self, elements: []const E) bool {
            for (elements) |el| {
                if (self.map.contains(el)) {
                    return true;
                }
            }
            return false;
        }

        /// difference returns the difference between this set
        /// and other. The returned set will contain
        /// all elements of this set that are not also
        /// elements of other.
        ///
        /// Caller owns the newly allocated/returned set.
        pub fn difference(self: *const Self, other: *const Self) Allocator.Error!Self {
            var diffSet = Self.init(self.allocator);

            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                if (!other.map.contains(entry.key_ptr.*)) {
                    _ = try diffSet.add(entry.key_ptr.*);
                }
            }
            return diffSet;
        }

        /// equals determines if two sets are equal to each
        /// other. If they have the same cardinality
        /// and contain the same elements, they are
        /// considered equal. The order in which
        /// the elements were added is irrelevant.
        pub fn equals(self: *const Self, other: *const Self) bool {
            // First discriminate on cardinalities of both sets.
            if (self.map.count() != other.map.count()) {
                return false;
            }

            // Now check for each element against the other.
            var iter = self.map.iterator();
            while (iter.next()) |entry| {
                if (!other.map.contains(entry.key_ptr.*)) {
                    return false;
                }
            }

            return true;
        }

        /// intersection returns a new set containing only the elements
        /// that exist only in both sets.
        ///
        /// Caller owns the newly allocated/returned set.
        pub fn intersection(self: *const Self, other: *const Self) Allocator.Error!Self {
            var interSet = Self.init(self.allocator);

            // Optimization, iterate over whichever set is smaller.
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
        pub fn intersectUpdate(self: *Self, other: *const Self) Allocator.Error!void {
            // I'm doing it this way because trying to do an in-place mutation
            // invalidates the iterators therefore a temp set is needed anyway.

            // Also, this saves a step of not having to possibly discard many elements
            // from the self set.

            // Just get a new set with the normal method.
            const interSet = try self.intersection(other);

            // Destroy the internal map.
            self.map.deinit();

            // Swap it out with the new set.
            self.map = interSet.map;
        }

        /// In place style:
        /// differenceUpdate
        /// symmetric_difference_update
        /// Returns true if the set is empty otherwise false
        pub fn isEmpty(self: *const Self) bool {
            return self.map.count() == 0;
        }

        /// isProperSubset determines if every element in this set is in
        /// the other set but the two sets are not equal.
        pub fn isProperSubset(self: *const Self, other: *const Self) bool {
            return self.map.count() < other.map.count() and self.IsSubset(other);
        }

        /// isProperSuperset determines if every element in the other set
        /// is in this set but the two sets are not equal.
        pub fn isProperSuperset(self: *const Self, other: *const Self) bool {
            return self.map.count() > other.map.count() and self.isSuperset(other);
        }

        /// isSubset determines if every element in this set is in
        /// the other set.
        pub fn isSubset(self: *const Self, other: *const Self) bool {
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

        /// isSubset determines if every element in the other Set is in
        /// the this Set.
        pub fn isSuperset(self: *const Self, other: *const Self) bool {
            // This is just the converse of isSubset.
            return other.isSubset(self);
        }

        pub fn iterator(self: *const Self) Iterator {
            return self.map.keyIterator();
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

        /// symmetricDifference returns a new set with all elements which are
        /// in either this set or the other set but not in both.
        ///
        /// The caller owns the newly allocated/returned Set.
        pub fn symmetricDifference(self: *const Self, other: *const Self) Allocator.Error!Self {
            var sdSet = Self.init(self.allocator);

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

        /// union returns a new set with all elements in both sets.
        ///
        /// The caller owns the newly allocated/returned Set.
        pub fn @"union"(self: *const Self, other: *const Self) Allocator.Error!Self {
            // Sniff out larger set for capacity hint.
            var n = self.map.count();
            if (other.map.count() > n) n = other.map.count();

            var uSet = try Self.initCapacity(
                self.allocator,
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
        pub fn unionUpdate(self: *Self, other: *const Self) Allocator.Error!void {
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

test "basic usage" {
    var set = Set(u32).init(std.testing.allocator);
    defer set.deinit();

    try expect(set.isEmpty());

    _ = try set.add(8);
    _ = try set.add(6);
    _ = try set.add(7);
    try expectEqual(set.cardinality(), 3);

    _ = try set.appendSlice(&.{ 5, 3, 0, 9 });

    // Positive cases.
    try expect(set.containsOne(8));
    try expect(set.containsAll(&.{ 5, 3, 9 }));
    try expect(set.containsAny(&.{ 5, 55, 12 }));

    // Negative cases.
    try expect(!set.containsOne(99));
    try expect(!set.containsAll(&.{ 8, 6, 77 }));
    try expect(!set.containsAny(&.{ 99, 55, 44 }));

    try expectEqual(set.cardinality(), 7);

    var other = Set(u32).init(std.testing.allocator);
    defer other.deinit();

    try expect(other.isEmpty());

    _ = try other.add(8);
    _ = try other.add(6);
    _ = try other.add(7);

    _ = try other.appendSlice(&.{ 5, 3, 0, 9 });

    try expect(set.equals(&other));
    try expectEqual(other.cardinality(), 7);

    try expect(other.remove(8));
    try expectEqual(other.cardinality(), 6);
    try expect(!other.remove(55));
    try expect(!set.equals(&other));

    other.removeAll(&.{ 6, 7 });
    try expectEqual(other.cardinality(), 4);

    // Intersection
    var inter = try set.intersection(&other);
    defer inter.deinit();
    try expect(!inter.isEmpty());
    try expectEqual(inter.cardinality(), 4);
    try expect(inter.containsAll(&.{ 5, 3, 0, 9 }));

    // Union
    var un = try set.@"union"(&other);
    defer un.deinit();
    try expect(!un.isEmpty());
    try expectEqual(un.cardinality(), 7);
    try expect(un.containsAll(&.{ 8, 6, 7, 5, 3, 0, 9 }));

    // Difference

    // Symmetric Difference

    // IsSubset

    // IsSuperset
}

test "clone" {
    {
        // clone
        var a = Set(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 20, 30, 40 });

        var b = try a.clone();
        defer b.deinit();

        try expect(a.equals(&b));
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

        try expect(a.allocator.ptr != b.allocator.ptr);
        try expect(a.equals(&b));
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
        // IsSubSet
        var a = Set(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 1, 2, 3, 5, 7 });

        var b = Set(u32).init(std.testing.allocator);
        defer b.deinit();

        // b should be a subset of a.
        try expect(b.isSubset(&a));

        _ = try b.add(72);

        // b should not be a subset of a, because 72 is not in a.
        try expect(!b.isSubset(&a));
    }

    {
        // IsSuperSet
        var a = Set(u32).init(std.testing.allocator);
        defer a.deinit();
        _ = try a.appendSlice(&.{ 9, 5, 2, 1, 11 });

        var b = Set(u32).init(std.testing.allocator);
        defer b.deinit();
        _ = try b.appendSlice(&.{ 5, 2, 11 });

        // set a should be a superset of set b
        try expect(!b.isSuperset(&a));

        _ = try b.add(42);

        // TODO: figure out why this fails.
        //set a should not be a superset of set b because b has 42
        // try expect(a.isSuperset(&b));
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
    // intersection_update
    var a = Set(u32).init(std.testing.allocator);
    defer a.deinit();
    _ = try a.appendSlice(&.{ 10, 20, 30, 40 });

    var b = Set(u32).init(std.testing.allocator);
    defer b.deinit();
    _ = try b.appendSlice(&.{ 44, 20, 30, 66 });

    try a.intersectUpdate(&b);
    try expectEqual(a.cardinality(), 2);
    try expect(a.containsAll(&.{ 20, 30 }));

    // union_update
    var c = Set(u32).init(std.testing.allocator);
    defer c.deinit();
    _ = try c.appendSlice(&.{ 10, 20, 30, 40 });

    var d = Set(u32).init(std.testing.allocator);
    defer d.deinit();
    _ = try d.appendSlice(&.{ 44, 20, 30, 66 });

    try c.unionUpdate(&d);
    try expectEqual(c.cardinality(), 6);
    try expect(c.containsAll(&.{ 10, 20, 30, 40, 66 }));
}
