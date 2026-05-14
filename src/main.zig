const std = @import("std");
const vaxis = @import("vaxis");
const Cell = vaxis.Cell;
const TextInput = vaxis.widgets.TextInput;

const Event = union(enum) {
	key_press: vaxis.Key,
	winsize: vaxis.Winsize,
	focus_in,
	foo: u8,
};

pub fn main(init: std.process.Init) !void {
  const io = init.io;
  const alloc = init.gpa;

	var buffer: [1024]u8 = undefined;
	var tty = try vaxis.Tty.init(io, &buffer);
	defer tty.deinit();

	var vx = try vaxis.init(io, alloc, init.environ_map, .{});
	defer vx.deinit(alloc, tty.writer());

	var loop: vaxis.Loop(Event) = .init(io, &tty, &vx);

	try loop.start();
	defer loop.stop();

	try vx.enterAltScreen(tty.writer());

	var color_idx: u8 = 0;

	var text_input = TextInput.init(alloc);
	defer text_input.deinit();

	try vx.queryTerminal(tty.writer(), .fromSeconds(1));

	while (true) {
		const event = try loop.nextEvent();

		switch (event) {
			.key_press => |key| {
				color_idx = switch (color_idx) {
					255 => 0,
					else => color_idx + 1,
				};
				if (key.matches('c', .{ .ctrl = true })) {
					break;
				} else if (key.matches('l', .{ .ctrl = true })) {
					vx.queueRefresh();
				} else {
					try text_input.update(.{ .key_press = key });
				}

			},

			.winsize => |ws| try vx.resize(alloc, tty.writer(), ws),
			else => {},
		}
		

		const win = vx.window();

		win.clear();

		const style: vaxis.Style = .{
			.fg = .{ .index = color_idx},
		};

		const child = win.child(.{
			.x_off = win.width / 2 - 20,
			.y_off = win.height / 2 - 3,
			.width = 40,
			.height = 3,
			.border = .{
				.where = .all,
				.style = style,
			},
		});

		text_input.draw(child);

		try vx.render(tty.writer());
	}
}
