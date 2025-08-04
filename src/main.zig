// API Docs:
// - https://kb.porkbun.com/article/190-getting-started-with-the-porkbun-api
// - https://porkbun.com/api/json/v3/documentation

const std = @import("std");
const log = std.log;
const mem = std.mem;
pub const std_options = std.Options{ .log_level = .debug };

const config = @import("config.zig");
const porkbun = @import("porkbun.zig");

pub fn main() !void {
    // var debug_alloc = std.heap.DebugAllocator(.{}).init;
    // const alloc = debug_alloc.allocator();

    const alloc = std.heap.smp_allocator;

    while (true) {
        config.init(alloc) catch |err| {
            log.err("Could not init config: {}", .{err});
            std.time.sleep(5 * std.time.ns_per_s);

            continue;
        };

        updateRecords(alloc) catch |err| {
            log.err("Could not update records: {}", .{err});
        };

        std.time.sleep(config.interval_ns);
    }
}

fn updateRecords(alloc: std.mem.Allocator) !void {
    log.info("Updating records", .{});

    var client = porkbun.new(alloc);
    defer client.deinit();

    if (config.ip_v4) {
        log.debug("Getting IPv4", .{});
        const ip_v4 = try client.getIpV4();
        log.info("IPv4: '{s}'", .{ip_v4});

        for (config.sub_domains) |record| {
            try client.checkRecord(&porkbun.Record{ .name = record, .type = "A", .content = ip_v4 });
        }
    }

    if (config.ip_v6) {
        log.debug("Getting IPv6", .{});
        const ip_v6 = try client.getIpV6();
        log.info("IPv6: '{s}'", .{ip_v6});

        for (config.sub_domains) |record| {
            try client.checkRecord(&porkbun.Record{ .name = record, .type = "AAAA", .content = ip_v6 });
        }
    }
    log.info("Done", .{});
}
