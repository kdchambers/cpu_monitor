const std = @import("std");
const assert = std.debug.assert;

const text_buffer_size = 1024;
var text_buffer: [text_buffer_size]u8 = undefined;

const Stat = struct {
    cpu_name: []const u8,
    user: u64,
    nice: u64,
    system: u64,
    idle: u64,
    iowait: u64,
    irq: u64,
    soft_irq: u64,

    total_idle: u64,
    total_busy: u64,

    pub inline fn log(self: @This()) void {
        const print = std.debug.print;
        print("cpu: {s}\n", .{self.cpu_name});
        print("  user:     {d}\n", .{self.user});
        print("  nice:     {d}\n", .{self.nice});
        print("  system:   {d}\n", .{self.system});
        print("  idle:     {d}\n", .{self.idle});
        print("  iowait:   {d}\n", .{self.iowait});
        print("  irq:      {d}\n", .{self.irq});
        print("  soft_irq: {d}\n", .{self.soft_irq});
    }
};

inline fn calculate_load(previous: Stat, current: Stat) f64 {
    const previous_total = previous.total_idle + previous.total_busy;
    const current_total = current.total_idle + current.total_busy;

    const total: f64 = @as(f64, @floatFromInt(current_total)) - @as(f64, @floatFromInt(previous_total));
    const idled: f64 = @as(f64, @floatFromInt(current.total_idle)) - @as(f64, @floatFromInt(previous.total_idle));

    const cpu_percentage: f64 = ((1000.0 * (total - idled)) / total + 1) / 10.0;
    return cpu_percentage;
}

fn load_stat_line(line: []const u8) !Stat {
    assert(line.len > 0);
    var stat: Stat = undefined;
    var i: usize = 0;
    stat.cpu_name = blk: {
        while (true) : (i += 1) {
            if (line[i] == ' ') {
                break :blk line[0..i];
            }
        }
        unreachable;
    };

    while (line[i] == ' ')
        i += 1;

    stat.user = blk: {
        const start_i: usize = i;
        while (true) : (i += 1) {
            if (line[i] < '0' or line[i] > '9') {
                const line_section = line[start_i..i];
                i += 1;
                break :blk try std.fmt.parseInt(u64, line_section, 10);
            }
        }
    };

    stat.nice = blk: {
        const start_i: usize = i;
        while (true) : (i += 1) {
            if (line[i] < '0' or line[i] > '9') {
                const line_section = line[start_i..i];
                i += 1;
                break :blk try std.fmt.parseInt(u64, line_section, 10);
            }
        }
    };

    stat.system = blk: {
        const start_i: usize = i;
        while (true) : (i += 1) {
            if (line[i] < '0' or line[i] > '9') {
                const line_section = line[start_i..i];
                i += 1;
                break :blk try std.fmt.parseInt(u64, line_section, 10);
            }
        }
    };

    stat.idle = blk: {
        const start_i: usize = i;
        while (true) : (i += 1) {
            if (line[i] < '0' or line[i] > '9') {
                const line_section = line[start_i..i];
                i += 1;
                break :blk try std.fmt.parseInt(u64, line_section, 10);
            }
        }
    };
    stat.iowait = blk: {
        const start_i: usize = i;
        while (true) : (i += 1) {
            if (line[i] < '0' or line[i] > '9') {
                const line_section = line[start_i..i];
                i += 1;
                break :blk try std.fmt.parseInt(u64, line_section, 10);
            }
        }
    };

    stat.irq = blk: {
        const start_i: usize = i;
        while (true) : (i += 1) {
            if (line[i] < '0' or line[i] > '9') {
                const line_section = line[start_i..i];
                i += 1;
                break :blk try std.fmt.parseInt(u64, line_section, 10);
            }
        }
    };
    stat.soft_irq = blk: {
        const start_i: usize = i;
        while (true) : (i += 1) {
            if (line[i] < '0' or line[i] > '9') {
                const line_section = line[start_i..i];
                i += 1;
                break :blk try std.fmt.parseInt(u64, line_section, 10);
            }
        }
    };

    stat.total_idle = stat.idle + stat.iowait;
    stat.total_busy = stat.user + stat.nice + stat.system + stat.irq + stat.soft_irq;

    return stat;
}

fn load_stat(stat_buffer: []Stat) ![]Stat {
    assert(stat_buffer.len >= 12);

    const stat_handle = try std.fs.openFileAbsolute("/proc/stat", .{});
    const file_stat = try stat_handle.stat();

    if (file_stat.size > text_buffer_size) {
        return error.StatFileTooLarge;
    }

    const bytes_read = try stat_handle.read(&text_buffer);

    var cpu_count: usize = 0;
    var i: usize = 0;
    outer: while (true) {
        const line_start = i;
        const line_end = blk: {
            while (i < bytes_read) : (i += 1) {
                if (text_buffer[i] == '\n') {
                    break :blk i;
                }
            }
            break :outer;
        };
        const line = text_buffer[line_start..line_end];
        stat_buffer[cpu_count] = try load_stat_line(line);
        cpu_count += 1;

        while (i < bytes_read and (text_buffer[i] == ' ' or text_buffer[i] == '\n'))
            i += 1;
    }
    return stat_buffer[0..cpu_count];
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    var thread_monitor = try ThreadUtilMonitor.init(allocator);
    std.log.info("Thread count: {d}", .{thread_monitor.perc_buffer.len});

    // const max_stat_count = 32;
    // var stat_buffer: [max_stat_count]Stat = undefined;
    // var buffer_offset: usize = 0;
    // var prev_stats = try load_stat(stat_buffer[buffer_offset..]);
    // while (true) {
    //     buffer_offset = (buffer_offset + @divExact(max_stat_count, 2)) % max_stat_count;
    //     std.time.sleep(std.time.ns_per_s);
    //     const next_stats = try load_stat(stat_buffer[buffer_offset..]);
    //     for (prev_stats, next_stats, 0..) |prev_stat, next_stat, i| {
    //         const percentage = calculate_load(prev_stat, next_stat);
    //         std.debug.print("  cpu_{d} :: {d:.2}\n", .{ i, percentage });
    //     }
    //     std.debug.print("\n", .{});
    //     prev_stats = next_stats;
    // }
}

const ThreadUtilMonitor = struct {
    stat_buffer: []Stat,
    perc_buffer: []f32,
    offset: u32,
    thread_count: u32,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        const stat_handle = try std.fs.openFileAbsolute("/proc/stat", .{});
        defer stat_handle.close();

        const file_stat = try stat_handle.stat();

        if (file_stat.size > text_buffer_size) {
            return error.StatFileTooLarge;
        }

        const bytes_read = try stat_handle.read(&text_buffer);

        var thread_count: usize = 0;
        var i: usize = 0;
        while (i < bytes_read) : (i += 1) {
            if (text_buffer[i] == '\n') {
                thread_count += 1;
            }
        }

        // The first line is just an aggregate of all the threads.
        thread_count -= 1;

        var stat_buffer = try allocator.alloc(Stat, thread_count * 2);
        var perc_buffer = try allocator.alloc(f32, thread_count);

        _ = load_stat(stat_buffer[0..thread_count]);

        return @This(){
            .stat_buffer = stat_buffer,
            .perc_buffer = perc_buffer,
            .offset = 0,
            .thread_count = thread_count,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.allocator) void {
        allocator.free(self.perc_buffer);
        allocator.free(self.stat_buffer);
        self.offset = undefined;
        self.thread_count = undefined;
    }

    pub fn update(self: *@This()) []f32 {
        const previous_stats = self.stat_buffer[self.offset .. self.offset + self.thread_count];
        const next_offset = (self.offset + self.thread_count) % (self.thread_count * 2);
        const stats = load_stat(self.stat_buffer[next_offset .. next_offset + self.thread_count]);
        for (previous_stats, stats, 0..) |prev, current, i| {
            self.perc_buffer[i] = calculate_load(prev, current);
        }
        self.offset = next_offset;
        return self.perc_buffer;
    }
};
