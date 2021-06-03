git clone git@github.com:Kong/gojira.git
export GOJIRA_MAGIC_DEV=1
export GOJIRA_USE_SNAPSHOT=1
export GOJIRA_TAG=2.2.0
./gojira/gojira.sh up --egg gojira-compose.yaml --git-https  
sleep 5s
gojira run "cd /kong/custom_plugins/circuit-breaker && luarocks make"
gojira run "bin/busted /kong/custom_specs/plugins/circuit-breaker/01-access_spec.lua -o custom_specs/output-handlers/custom_format.lua"
