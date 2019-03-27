# Minimal steps to tear down a site deployed using speedrun.sh

[[ ! -z "$SITE" ]] || exit

pushd ${SITE}/bakerydemo && \
source  ../venv/bin/activate && \
zappa undeploy dev -y  && \
deactivate && \
popd && \
aws s3 rb s3://${SITE}-static --force --profile iam-zappa && \
aws s3 rb s3://${SITE}-db --force --profile iam-zappa && \
aws s3 rb s3://${SITE}-zappa --force --profile iam-zappa && \
aws iam delete-role-policy --role-name ${SITE}-dev-ZappaLambdaExecutionRole \
    --policy-name zappa-permissions --profile iam-zappa  && \
aws iam delete-role --role-name ${SITE}-dev-ZappaLambdaExecutionRole --profile iam-zappa  && \
rm -rf ${SITE}
