const std = @import("std");
const proc = std.process;
const log = std.log;
const mem = std.mem;
const fmt = std.fmt;
const time = std.time;

const types = @import("types.zig");

pub var api_key: []const u8 = undefined;
pub var secret_key: []const u8 = undefined;
pub var domain: []const u8 = undefined;
pub var records: []const types.Record = undefined;
pub var interval_ns: u64 = undefined;

pub fn init(allocator: mem.Allocator) !void {
    api_key = try getEnv(allocator, "API_KEY") orelse {
        log.err("API_KEY env var is required", .{});
        return error.MissingEnvVar;
    };
    secret_key = try getEnv(allocator, "SECRET_KEY") orelse {
        log.err("SECRET_KEY env var is required", .{});
        return error.MissingEnvVar;
    };
    domain = try getEnv(allocator, "DOMAIN") orelse {
        log.err("DOMAIN env var is required", .{});
        return error.MissingEnvVar;
    };
    const interval = try getEnvInt(allocator, "INTERVAL") orelse 60;
    interval_ns = interval * time.ns_per_s;

    records = try getRecords(allocator);
}

fn getEnv(allocator: mem.Allocator, comptime name: []const u8) !?[]const u8 {
    var val = proc.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        proc.GetEnvVarOwnedError.EnvironmentVariableNotFound => "",
        else => {
            log.err("Could not get env var '{s}'", .{name});
            return err;
        },
    };

    if (val.len != 0) {
        return val;
    }

    const path = std.process.getEnvVarOwned(allocator, name ++ "_FILE") catch |err| switch (err) {
        proc.GetEnvVarOwnedError.EnvironmentVariableNotFound => "",
        else => {
            log.err("Could not get env var '{s}_FILE'", .{name});
            return err;
        },
    };

    if (path.len == 0) {
        return null;
    }

    const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
        log.err("Could not open '{s}_FILE' at {s}", .{ name, path });
        return err;
    };
    defer file.close();

    val = file.readToEndAlloc(allocator, 1 * 1024 * 1024) catch |err| {
        log.err("Could not open '{s}_FILE' at {s}", .{ name, path });
        return err;
    };

    return if (val.len != 0) val else null;
}

fn getEnvInt(allocator: mem.Allocator, comptime name: []const u8) !?u64 {
    const val = try getEnv(allocator, name);

    return if (val) |it| try fmt.parseInt(u64, it, 10) else null;
}

fn getRecords(allocator: mem.Allocator) ![]types.Record {
    const sub_domains = try getEnv(allocator, "SUB_DOMAINS") orelse "";

    var it = mem.splitScalar(u8, sub_domains, ',');
    var records_list = std.ArrayList(types.Record).init(allocator);
    defer records_list.deinit();

    while (it.next()) |sub_domain| {
        try records_list.append(types.Record{ .name = sub_domain, .type = "A" });
        // try records_list.append(types.Record{ .name = sub_domain, .type = "AAAA" });
    }

    return records_list.toOwnedSlice();
}
