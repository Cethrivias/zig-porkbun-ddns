// API Docs:
// - https://kb.porkbun.com/article/190-getting-started-with-the-porkbun-api
// - https://porkbun.com/api/json/v3/documentation

const std = @import("std");
const log = std.log;
pub const std_options = std.Options{ .log_level = .debug };

const porkbun = @import("porkbun.zig");
const config = @import("config.zig");

pub fn main() !void {
    // var debug_alloc = std.heap.DebugAllocator(.{}).init;
    // const alloc = debug_alloc.allocator();

    const alloc = std.heap.smp_allocator;

    while (true) {
        try config.init(alloc);

        try updateRecords(alloc);

        std.time.sleep(config.interval_ns);
    }
}

fn updateRecords(alloc: std.mem.Allocator) !void {
    log.info("Updating records", .{});

    var client = porkbun.new(alloc);
    defer client.deinit();

    log.debug("Getting IPv4", .{});
    const ip_v4 = try client.getIpV4();
    log.info("IPv4: '{s}'", .{ip_v4});

    log.debug("Getting IPv6", .{});
    const ip_v6 = try client.getIpV6();
    log.info("IPv6: '{s}'", .{ip_v6});

    for (config.records) |record| {
        log.debug("Checking '{s}' record for '{s}.{s}'", .{ record.type, record.name, config.domain });
        const ip = if (std.mem.eql(u8, record.type, "A")) ip_v4 else ip_v6;

        const dns_record = try client.getDnsRecord(config.domain, &record);

        if (dns_record == null) {
            log.info(
                "Creating '{s}' record for '{s}.{s}'. IP: {s}",
                .{ record.type, record.name, config.domain, ip },
            );

            try client.createDnsRecord(config.domain, &record, ip);
            continue;
        }

        if (std.mem.eql(u8, dns_record.?.content, ip)) {
            continue;
        }

        log.info(
            "Updating '{s}' record for '{s}.{s}'. IP: '{s}' -> '{s}'",
            .{ record.type, record.name, config.domain, dns_record.?.content, ip },
        );

        try client.updateDnsRecord(config.domain, &record, ip);
    }
    log.info("Done", .{});
}
