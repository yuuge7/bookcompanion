These files were produced using `Book.toJson` and `ReadingSession.toJson` from
the repository tags v1.0 through v1.5. They contain synthetic finished and open
reads, including ratings and page progress. v1.5 adds date precision; earlier
exports omit it and must continue to load as exact dates.

Keep these fixtures when changing the schema. They are the compatibility promise
for every released JSON export format, not disposable test output.
