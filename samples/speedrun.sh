# See nealtodd.github.io/serverless-django/djconeu-speedrun

[[ ! -z "$SITE" ]] || exit

mkdir ${SITE} && cd ${SITE}

python3 -m venv ./venv
source ./venv/bin/activate
pip install --upgrade pip

pip install zappa zappa-django-utils django-storages awscli

git clone https://github.com/wagtail/bakerydemo.git
cd bakerydemo
pip install -r requirements/base.txt

cat << EOF >> bakerydemo/settings/dev.py
DATABASES = {
    'default': {
        'ENGINE': 'zappa_django_utils.db.backends.s3sqlite',
        'NAME': '${SITE}-sqlite.db',
        'BUCKET': '${SITE}-db'
    }
}

ALLOWED_HOSTS = ['.eu-west-2.amazonaws.com', '.bygge.net']

INSTALLED_APPS += ('storages',)
AWS_STORAGE_BUCKET_NAME = '${SITE}-static'
AWS_QUERYSTRING_AUTH = False
STATICFILES_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
EOF

cat << EOF > zappa_settings.json
{
    "dev": {
        "django_settings": "bakerydemo.settings.dev",
        "profile_name": "iam-zappa",
        "project_name": "${SITE}",
        "runtime": "python3.6",
        "s3_bucket": "${SITE}-zappa",
        "aws_region": "eu-west-2",
        "timeout_seconds": 60,
        "domain": "${SITE}.bygge.net",
        "certificate_arn": "${CERT_ARN}",
        "aws_environment_variables": {
            "DEBUG": "false"
    	}
    }
}
EOF

aws s3api create-bucket --bucket ${SITE}-db --profile iam-zappa \
	--region eu-west-2 --create-bucket-configuration LocationConstraint=eu-west-2
aws s3api create-bucket --bucket ${SITE}-static --profile iam-zappa \
	--region eu-west-2 --create-bucket-configuration LocationConstraint=eu-west-2
aws s3api put-bucket-cors --bucket ${SITE}-static --profile iam-zappa --cors-configuration \
	'{"CORSRules": [{"AllowedOrigins": ["*"], "AllowedMethods": ["GET"]}]}'
aws s3api put-bucket-policy --bucket ${SITE}-static --profile iam-zappa --policy \
	'{"Statement": [{"Effect": "Allow","Principal": "*","Action": "s3:GetObject","Resource": "arn:aws:s3:::'${SITE}'-static/*"}]}'
aws s3 sync bakerydemo/media/original_images/ s3://${SITE}-static/original_images/ --profile iam-zappa

zappa deploy dev
zappa certify dev -y
zappa manage dev "collectstatic --noinput"
zappa manage dev migrate
zappa manage dev load_initial_data
zappa status dev
