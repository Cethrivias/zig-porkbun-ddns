const std = @import("std");
const proc = std.process;
const log = std.log;
const mem = std.mem;
const fmt = std.fmt;
const time = std.time;

pub var api_key: []const u8 = undefined;
pub var secret_key: []const u8 = undefined;
pub var domain: []const u8 = undefined;
pub var sub_domains: [][]const u8 = undefined;
pub var interval_ns: u64 = undefined;
pub var ip_v4: bool = undefined;
pub var ip_v6: bool = undefined;

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
    sub_domains = try getSubDomains(allocator);

    const interval = try getEnvInt(allocator, "INTERVAL") orelse 60;
    interval_ns = interval * time.ns_per_s;

    ip_v4 = try getEnvBool(allocator, "IP_V4") orelse true;
    ip_v6 = try getEnvBool(allocator, "IP_V6") orelse false;
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

fn getEnvBool(allocator: mem.Allocator, comptime name: []const u8) !?bool {
    const val = try getEnv(allocator, name);

    return if (val) |it| mem.eql(u8, it, "TRUE") else null;
}

fn getSubDomains(allocator: mem.Allocator) ![][]const u8 {
    const sub_domains_env = try getEnv(allocator, "SUB_DOMAINS") orelse "";

    var it = mem.splitScalar(u8, sub_domains_env, ',');
    var sub_domains_list = std.ArrayList([]const u8).init(allocator);
    defer sub_domains_list.deinit();

    while (it.next()) |sub_domain| {
        try sub_domains_list.append(sub_domain);
    }

    return sub_domains_list.toOwnedSlice();
}
