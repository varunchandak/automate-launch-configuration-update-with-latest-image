#!/bin/bash

# This script will do the following (in order):
#	- Get a list of instances running inside the autoscaling group
#	- Create an AMI of any random instance and store AMI ID. Alternatively, pass the instance ID to use that instance instead of any random.
#	- fetch the launch configuration name to an autoscaling group (ASG passed as parameter to script)
#	- create a new launch configuration with the updated image
#	- Assign the Launch Configuration to the existing Auto Scaling Group (ASG)
#	- Removal of old Launch Configurations (commented for now)
#
# NOTES:
#	When you change the launch configuration for your Auto Scaling group, 
#		any new instances are launched using the new configuration parameters, 
#		but existing instances are not affected.

usage() {
	echo "See the README HERE: https://github.com/varunchandak/automate-launch-configuration-update-with-latest-image"
}


if [ "$#" -ne 3  ] && [ "$#" -ne 4 ]; then
	usage
else
	# export AWS PROFILES
	export AWS_DEFAULT_PROFILE="$1"
	export AWS_DEFAULT_REGION="$2"
	export ASG_NAME="$3"
	export INSTANCE_ID="$4"
	export DATETODAY=$(date +%d%m%Y)

	# Initializing Logic:
	# Setting aws binary location alias
	alias aws=''`which aws`' --output text'
	if [[ "$OSTYPE" == "darwin"* ]]; then
		alias awk='/usr/local/bin/gawk'
		alias date='/usr/local/bin/gdate'
	fi

	shopt -s expand_aliases

	# Get launch configuration name from ASG_NAME
	export LC_NAME="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[].LaunchConfigurationName')"
	export NEW_LC_NAME="$(echo $LC_NAME | awk -F- 'sub(FS $NF,x)')"-"$DATETODAY"

	if [ ! -z "$INSTANCE_ID" ]; then
		echo "Using $INSTANCE_ID instead of random instance."
		export RANDOM_INST_ID="$INSTANCE_ID"
	else
		# Get 1 random instance ID from the list of instances running under ASG_NAME
		echo "Using any random instance from $ASG_NAME ASG."
		export RANDOM_INST_ID="$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[].Instances[?HealthStatus==`Healthy`].InstanceId' | tr -s '\t' '\n' | shuf -n 1)";
	fi
	if [ -z "$RANDOM_INST_ID" ]; then
		echo "No instances running in this ASG; Quitting"
		exit 1
	else
		# Create AMI from the Instance without reboot
		export AMI_ID="$(aws ec2 create-image --instance-id $RANDOM_INST_ID --name "$ASG_NAME"-"$DATETODAY" --no-reboot)"

		if [ ! -z "$AMI_ID" ]; then
			# Wait for image to complete
			while true; do
				export AMI_STATE="$(aws ec2 describe-images --filters Name=image-id,Values="$AMI_ID" --query 'Images[*].State')"
				if [ "$AMI_STATE" == "available" ]; then
					# Extract existing launch configuration
					aws autoscaling describe-launch-configurations --launch-configuration-names "$LC_NAME" --output json --query 'LaunchConfigurations[0]' > /tmp/"$LC_NAME".json

					# Remove unnecessary and empty entries from the launch configuration JSON and fill up with latest AMI ID
					cat /tmp/"$LC_NAME".json | \
						jq 'walk(if type == "object" then with_entries(select(.value != null and .value != "" and .value != [] and .value != {} and .value != [""] )) else . end )' | \
						jq 'del(.CreatedTime, .LaunchConfigurationARN, .BlockDeviceMappings)' | \
						jq ".ImageId = \"$AMI_ID\" | .LaunchConfigurationName = \"$NEW_LC_NAME\"" > /tmp/"$NEW_LC_NAME".json

					# Create new launch configuration with new name
					if [ -z "$(jq .UserData /tmp/$LC_NAME.json --raw-output)" ]; then
						aws autoscaling create-launch-configuration --cli-input-json file:///tmp/"$NEW_LC_NAME".json
					else
						aws autoscaling create-launch-configuration --cli-input-json file:///tmp/"$NEW_LC_NAME".json --user-data file://<(jq .UserData /tmp/"$NEW_LC_NAME".json --raw-output | base64 --decode)
					fi

					# Update autoscaling group with new launch configuration
					aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" --launch-configuration-name "$NEW_LC_NAME"

					# Resetting aws binary alias
					unalias aws
					break
				fi
				echo "AMI creation still under progress. Retrying in 15 seconds..."
				sleep 15
			done
		else
			echo "Error creating AMI"
			exit 1
		fi
	fi
fi
