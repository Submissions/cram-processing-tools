# Using the App node for the cram-processing pipeline

**The current practice is to use the login nodes to carry out the steps in the cram-processing pipeline.
Automation of cram-processing-tools reflects this practice.**

## Demonstration of how to use an app-node as an alternative to the login-node.

- Login nodes are usually for data transfer with laptop
    - Example: `rsync my_directory sug-login1.hgsc.bcm.edu:/groups/submissions/users/person`

- On laptop, this script...:
	```
	(main) bin$ cat sa1
	#!/usr/bin/env bash

	login_host=${DEFAULT_SUG_LOGIN:-$s4}

	ssh -t $login_host ssh sug-app1 "$@"
	```
- ...Is equivalent to:
	```
	ssh -t sug-login4.hgsc.bcm.edu ssh sug-app1
	```

- The -t on the outer ssh says:
    - Do not allocate a pseudo-terminal, just pass the connection through to the inner ssh, which will allocate the one pseudo-terminal
