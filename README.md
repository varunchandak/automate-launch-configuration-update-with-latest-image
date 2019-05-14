# Auto update ASG with latest image and launch configuration

## Usage:

### For any random instance

```
./automate-launch-configuration-update-with-latest-image.sh <AWS_PROFILE> <AWS_REGION> <ASG_NAME>
```

### For a particular instance inside ASG
```
./automate-launch-configuration-update-with-latest-image.sh <AWS_PROFILE> <AWS_REGION> <ASG_NAME> <INSTANCE_ID>
```

---

This script will do the following (in order):

1. Get a list of instances running inside the autoscaling group, only if instance ID is not provided.
2. Create an AMI of any random instance and store AMI ID. *Alternatively, pass the instance ID to use that instance instead of any random.*
3. Fetch the launch configuration name to an autoscaling group (passed as parameter to script)
4. Create a new launch configuration with the updated image
5. Assign the Launch Configuration to the existing Auto Scaling Group (ASG)
6. Removal of old Launch Configurations (commented for now)

---

## NOTES:
* Before running the script on OSX, make sure to install `gawk` under `/usr/local/bin/` and `gdate` under `/usr/local/bin/` folders.
* `jq` version > 1.6 required.
* When you change the launch configuration for your Auto Scaling group, any new instances are launched using the new configuration parameters, but existing instances are not affected. This is the default configuration.
* **RUN THIS ON TEST ENVIRONMENT FIRST. I AM NOT RESPONSIBLE FOR ANY UNINTENDED DAMAGE.**
