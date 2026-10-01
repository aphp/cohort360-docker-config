#!/bin/sh
set -e

# sed -i "s@{BACK_URL}@$BACK_URL@g" /etc/nginx/conf.d/nginx.conf

sed -i "s@{VITE_BACK_API_URL}@$VITE_BACK_API_URL@g" /app/build/assets/*.js
sed -i "s@{VITE_USERNAME_REGEX}@$VITE_USERNAME_REGEX@g" /app/build/assets/*.js

sed -i "s@{VITE_OIDC_PROVIDER_URL}@$VITE_OIDC_PROVIDER_URL@g" /app/build/assets/*.js
sed -i "s@{VITE_OIDC_REDIRECT_URI}@$VITE_OIDC_REDIRECT_URI@g" /app/build/assets/*.js
sed -i "s@{VITE_OIDC_RESPONSE_TYPE}@$VITE_OIDC_RESPONSE_TYPE@g" /app/build/assets/*.js
sed -i "s@{VITE_OIDC_CLIENT_ID}@$VITE_OIDC_CLIENT_ID@g" /app/build/assets/*.js
sed -i "s@{VITE_OIDC_SCOPE}@$VITE_OIDC_SCOPE@g" /app/build/assets/*.js
sed -i "s@{VITE_OIDC_STATE}@$VITE_OIDC_STATE@g" /app/build/assets/*.js

sed -i "s@{VITE_CODE_DISPLAY_JWT}@$VITE_CODE_DISPLAY_JWT@g" /app/build/assets/*.js

sed -i "s@{VITE_ROOT_PERIMETER_TYPE}@$VITE_ROOT_PERIMETER_TYPE@g" /app/build/assets/*.js

sed -i "s@{VITE_USE_CHECKED_PROFILES}@$VITE_USE_CHECKED_PROFILES@g" /app/build/assets/*.js
sed -i "s@{VITE_ENABLE_DATALABS}@$VITE_ENABLE_DATALABS@g" /app/build/assets/*.js
sed -i "s/{VITE_MAIL_SUPPORT}/$VITE_MAIL_SUPPORT/g" /app/build/assets/*.js
sed -i "s/{VITE_MAIL_REGEX}/$VITE_MAIL_REGEX/g" /app/build/assets/*.js


service nginx restart

sleep infinity