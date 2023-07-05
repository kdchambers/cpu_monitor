const std = @import("std");
const assert = std.debug.assert;

// const max_line_size = 512;
// var line_buffer: [max_line_size]u8 = undefined;

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

const max_stat_count = 16;
var stat_buffer: [max_stat_count]Stat = undefined;

fn load_stat() ![]Stat {
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
        std.log.info("Stat for line: {s}", .{line});
        stat_buffer[cpu_count] = try load_stat_line(line);
        cpu_count += 1;

        while (i < bytes_read and (text_buffer[i] == ' ' or text_buffer[i] == '\n'))
            i += 1;
    }
    return stat_buffer[0..cpu_count];
}

pub fn main() !void {
    const cpu_stats = try load_stat();

    _ = cpu_stats;

    // var stat_0 = try load_stat();
    // while (true) {
    //     std.time.sleep(std.time.ns_per_s);
    //     const stat_1 = try load_stat();
    //     const load_percentage = calculate_load(stat_0, stat_1);
    //     std.debug.print("{d:.2}%\n", .{load_percentage});
    //     stat_0 = stat_1;
    // }
}
