# helper scripts for NBC benchmarking

process\_benchmark\_output.pl - takes NBC benchmark output and converts it into a
JSON file suitable for the [Jenkins Benchmark
plugin](https://plugins.jenkins.io/benchmark/).

run\_nbc\_benchmarks.sh - builds and runs benchmarks, then calls process\_benchmark\_output.pl on their outputs.

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.

