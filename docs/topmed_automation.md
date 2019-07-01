# TOPmed Automation

`topmed_automation` is a bash script that runs a majority of steps for cram processing.

**As of now, the user is still responsible for:**
- Checking if aspera has sufficient space.
- Checking validation after it is done.
- Copying the crams over to aspera with the generated copy script.
- Creating the manifest and copying it to aspera with `topmed_md5_prep_shep.sh`

## Setup

#### Passwordless Entry

You must have passwordless entry when using `ssh` to a copy node.

- ssh into the login node. `ssh USERNAME@sug-login#.hgsc.bcm.edu`
- `cd .ssh`. You should have a `id_rsa.pub` file and a `authorized_keys` file.
- Append your public key to the authorized_keys file. `cat id_rsa.pub >> autorized_keys`

You should no longer need to enter your password when login to any of the other nodes.


## How to Run
To run the script type: `./topmed_automation PM_CODE PM_PATH`

- `PM_CODE` is the project code that is given in the RT. An example code would be `proj-dm0021`.
- `PM_PATH` is the path given to you by the project manager. An example path would look like this: `/hgsc_software/groups/project-managers/tech/metadata/v1/topmed/YR3/cardiomyopathy/01/03a`


## Workflow

- Check if `shepherd.yaml` exist in the users `.config` directory.
    - If it does, proceed.
    - It it does not, the `shepherd.yaml` file will be created and then proceeds.
- Checks if previous named tmux sessions `topmed-copy` and `topmed-login` exist.
    - It if it does, the user will need to manually close it just in case they have an important task running.
    - If it does not, proceed.
- Run shepherd's `accept_batch` script.
- Generate the copy script with `generate-topmed-copy-script-tsv`
- Generate the md5_worklist script with `generate-topmed-md5-worklist-tsv`
- Create the input directory under `validation/`
- Create symlinks to all the crams in the input directory
- In the `topmed-login` session, submit md5 jobs to the cluster with the `submit-md5-jobs` script.
- In the `topmed-login` session, run validation with the `submit-cram-validation_phase5`script.
