#!/bin/bash

read -p "Name for your CloudFormation stack: " -e STACK_NAME

#STACK_Name=jcook-test

echo "Submitting request to create stack ${STACK_NAME}"
# Note the capability "CAPABILITY_IAM" is required to create the Lambda execution role
aws cloudformation create-stack --stack-name ${STACK_NAME} --capabilities CAPABILITY_IAM --template-body file://cloudformation/template.json --output text

echo "Creation request submitted, waiting until it is done (this will take several minutes)..."
# Typically this takes about 20 minutes for me
aws cloudformation wait stack-create-complete --stack-name ${STACK_NAME}
exit_code=$?
if [ ${exit_code} -ne 0 ]; then
	# Uh-oh, we ran into a problem. Show the user a list of events to help guide them.
	echo ""
	aws cloudformation describe-stack-events --stack-name ${STACK_NAME} --query "StackEvents[*].{Date:Timestamp,Name:LogicalResourceId,Status:ResourceStatus,StatusText:ResourceStatusReason}" --output table
	echo -e "\nCreation of the stack failed. See the list of events above to understand what went wrong."
	echo -e "\nYou might want to run the following to clean up:"
	echo "  aws cloudformation delete-stack --stack-name ${STACK_NAME}"
	exit ${exit_code}
fi

echo "Stack creation complete! Uploading static files to S3."
BUCKET=`aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" --output text`
# Note the public-read ACL is required
aws s3 cp --recursive --acl public-read static/ s3://${BUCKET}/

SITE_URL=`aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='SiteURL'].OutputValue" --output text`
echo -e "\nAll done, you can access your new website here: ${SITE_URL}"
echo -e "\nTo cleanup the stack, execute these two commands:"
echo "  aws s3 rm --recursive s3://${BUCKET}/"
echo "  aws cloudformation delete-stack --stack-name ${STACK_NAME}"
