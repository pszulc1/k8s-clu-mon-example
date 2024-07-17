local date = std.extVar('date');
local labels = ['black', 'blue', 'orange'];

{
  streams: [
    {
      stream: {
        agent: 'the-one',
        colour: labels[std.parseInt(date[std.length(date) - 1]) % 3],
      },
      values: [
        [
          date,
          'level=INFO logger=amdtc env=prod793 msg=\"The very important message\" ' 
          + 'bytes=' + date[std.length(date) - 7:std.length(date)],
        ],
      ],
    },
  ],
}
