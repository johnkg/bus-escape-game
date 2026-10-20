/// Whole days since 1 Jan 2024 for the calendar date of [d] (local time),
/// so everyone playing on the same date gets the same daily challenge.
int dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024)).inDays;
