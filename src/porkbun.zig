const std = @import("std");
const config = @import("config.zig");
const types = @import("types.zig");

pub fn new(allocator: std.mem.Allocator) Client {
    return Client{
        .allocator = allocator,
        .config = Config{ .apikey = config.api_key, .secretapikey = config.secret_key },
        .client = std.http.Client{ .allocator = allocator },
    };
}

pub const Client = struct {
    allocator: std.mem.Allocator,
    config: Config,
    client: std.http.Client,

    pub fn deinit(self: *Client) void {
        self.client.deinit();
    }

    fn post(self: *Client, T: type, url: []const u8, req: anytype) !T {
        var res_body = std.ArrayList(u8).init(self.allocator);
        defer res_body.deinit();

        const payload = try std.json.stringifyAlloc(self.allocator, req, .{});

        _ = try self.client.fetch(.{
            .method = .POST,
            .location = .{ .url = url },
            .payload = payload,
            .response_storage = .{ .dynamic = &res_body },
        });

        const json = try std.json.parseFromSlice(T, self.allocator, res_body.items, .{ .ignore_unknown_fields = true });

        return json.value;
    }

    fn get(self: *Client, url: []const u8) ![]const u8 {
        var res_body = std.ArrayList(u8).init(self.allocator);
        defer res_body.deinit();

        _ = try self.client.fetch(.{
            .method = .GET,
            .location = .{ .url = url },
            .response_storage = .{ .dynamic = &res_body },
        });

        return res_body.toOwnedSlice();
    }

    pub fn getIpV4(self: *Client) ![]const u8 {
        const res = try self.get("https://v4.i-p.show/?plain=true");
        const ip = res[0 .. res.len - 1];

        _ = try std.net.Ip4Address.parse(ip, 0);

        return ip;
    }

    pub fn getIpV6(self: *Client) ![]const u8 {
        const res = try self.get("https://v6.i-p.show/?plain=true");
        const ip = res[0 .. res.len - 1];
        // const res = try self.post(IpResponse, "https://api.porkbun.com/api/json/v3/ping", self.config);

        // _ = try std.net.Ip6Address.parse(res.yourIp, 0);
        _ = try std.net.Ip6Address.parse(ip, 0);

        return ip;
    }

    pub fn getDnsRecords(self: *Client, domain_name: []const u8) ![]DnsResponse {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "https://api.porkbun.com/api/json/v3/dns/retrieve/{s}",
            .{domain_name},
        );
        const res = try self.post(GetDnsResponse, url, self.config);

        return res.records;
    }

    pub fn getDnsRecord(self: *Client, domain_name: []const u8, record: *const types.Record) !?DnsResponse {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "https://api.porkbun.com/api/json/v3/dns/retrieveByNameType/{s}/{s}/{s}",
            .{ domain_name, record.type, record.name },
        );

        const res = try self.post(GetDnsResponse, url, self.config);

        return if (res.records.len != 0) res.records[0] else null;
    }

    pub fn createDnsRecord(self: *Client, domain_name: []const u8, record: *const types.Record, ip: []const u8) !void {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "https://api.porkbun.com/api/json/v3/dns/create/{s}",
            .{domain_name},
        );
        const req = DnsRequest{
            .apikey = self.config.apikey,
            .secretapikey = self.config.secretapikey,
            .name = record.name,
            .type = record.type,
            .content = ip,
        };
        _ = try self.post(Response, url, req);
    }

    pub fn updateDnsRecord(self: *Client, domain_name: []const u8, record: *const types.Record, ip: []const u8) !void {
        const url = try std.fmt.allocPrint(
            self.allocator,
            "https://api.porkbun.com/api/json/v3/dns/editByNameType/{s}/{s}/{s}",
            .{ domain_name, record.type, record.name },
        );

        _ = try self.post(Response, url, .{
            .apikey = self.config.apikey,
            .secretapikey = self.config.secretapikey,
            .content = ip,
            .ttl = "600",
        });
    }
};

const Config = struct {
    apikey: []const u8,
    secretapikey: []const u8,
};

const Response = struct { status: []u8 };

pub const IpResponse = struct { status: []u8, yourIp: []u8 };

pub const DnsResponse = struct {
    id: []u8,
    name: []u8,
    type: []u8, // A, AAAA
    content: []u8, // ip
    ttl: []u8, //"600",
    prio: ?[]u8, // ["0"],
    notes: ?[]u8,
};

pub const DnsRequest = struct {
    secretapikey: []const u8,
    apikey: []const u8,
    name: []const u8,
    type: []const u8,
    content: []const u8,
    ttl: []const u8 = "600",
};

pub const GetDnsResponse = struct { status: []u8, records: []DnsResponse };
