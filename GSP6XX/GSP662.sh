PROJECT=$(gcloud config list project 2>/dev/null | grep = | sed "s/^[^=]*= //")
read -p "Enter zone provided by lab: " ZONE
read -p "Enter region provided by lab: " REGION

echo "Task 1 - Enable Compute Engine API"
read -p "Press enter to continue"

gcloud services enable compute.googleapis.com

read -p "Checkpoint. Press Enter to continue"
echo "Task 2 - Create Cloud Storage bucket"
read -p "Press enter to continue"

gsutil mb gs://fancy-store-$PROJECT

read -p "Checkpoint. Press Enter to continue"
echo "Task 3 - Clone source repository"
read -p "Press enter to continue"

cd
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh
nvm install --lts

read -p "Checkpoint. Press Enter to continue"
echo "Task 4 - Create Compute Engine instances"
read -p "Press enter to continue"

echo "#!/bin/bash
# Install logging monitor. The monitor will automatically pick up logs sent to
# syslog.
curl -s "https://storage.googleapis.com/signals-agents/logging/google-fluentd-install.sh" | bash
service google-fluentd restart &
# Install dependencies from apt
apt-get update
apt-get install -yq ca-certificates git build-essential supervisor psmisc
# Install nodejs
mkdir /opt/nodejs
curl https://nodejs.org/dist/v16.14.0/node-v16.14.0-linux-x64.tar.gz | tar xvzf - -C /opt/nodejs --strip-components=1
ln -s /opt/nodejs/bin/node /usr/bin/node
ln -s /opt/nodejs/bin/npm /usr/bin/npm
# Get the application source code from the Google Cloud Storage bucket.
mkdir /fancy-store
gsutil -m cp -r gs://fancy-store-{QWIKLABPROJECTID}/monolith-to-microservices/microservices/* /fancy-store/
# Install app dependencies.
cd /fancy-store/
npm install
# Create a nodeapp user. The application will run as this user.
useradd -m -d /home/nodeapp nodeapp
chown -R nodeapp:nodeapp /opt/app
# Configure supervisor to run the node app.
cat >/etc/supervisor/conf.d/node-app.conf << EOF
[program:nodeapp]
directory=/fancy-store
command=npm start
autostart=true
autorestart=true
user=nodeapp
environment=HOME=\"/home/nodeapp\",USER=\"nodeapp\",NODE_ENV=\"production\"
stdout_logfile=syslog
stderr_logfile=syslog
EOF
supervisorctl reread
supervisorctl update" >> ~/monolith-to-microservices/startup-script.sh

sed -i "s/{QWIKLABPROJECTID}/$PROJECT/g" ~/monolith-to-microservices/startup-script.sh

gsutil cp ~/monolith-to-microservices/startup-script.sh gs://fancy-store-$PROJECT

cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$PROJECT/

gcloud compute instances create backend \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --tags=backend \
   --metadata=startup-script-url=https://storage.googleapis.com/fancy-store-$PROJECT/startup-script.sh
   
command_output=$(gcloud compute instances list)
backendUrl=$(echo "$command_output" | awk '/^EXTERNAL_IP:/ { print $2 }')
sed -i "s/localhost/$backendUrl/g" ~/monolith-to-microservices/react-app/.env

cd ~/monolith-to-microservices/react-app
npm install && npm run-script build

cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$PROJECT/

gcloud compute instances create frontend \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --tags=frontend \
    --metadata=startup-script-url=https://storage.googleapis.com/fancy-store-$PROJECT/startup-script.sh
	
gcloud compute firewall-rules create fw-fe \
    --allow tcp:8080 \
    --target-tags=frontend
	
gcloud compute firewall-rules create fw-be \
    --allow tcp:8081-8082 \
    --target-tags=backend

read -p "Checkpoint. Press Enter to continue"
echo "Task 5 - Create managed instance groups"
read -p "Press enter to continue"

gcloud compute instances stop frontend --zone=$ZONE
gcloud compute instances stop backend --zone=$ZONE

gcloud compute instance-templates create fancy-fe \
    --source-instance-zone=$ZONE \
    --source-instance=frontend
	
gcloud compute instance-templates create fancy-be \
    --source-instance-zone=$ZONE \
    --source-instance=backend

gcloud compute instances delete backend --zone=$ZONE

gcloud compute instance-groups managed create fancy-fe-mig \
    --zone=$ZONE \
    --base-instance-name fancy-fe \
    --size 2 \
    --template fancy-fe
	
gcloud compute instance-groups managed create fancy-be-mig \
    --zone=$ZONE \
    --base-instance-name fancy-be \
    --size 2 \
    --template fancy-be
	
gcloud compute instance-groups set-named-ports fancy-fe-mig \
    --zone=$ZONE \
    --named-ports frontend:8080
	
gcloud compute instance-groups set-named-ports fancy-be-mig \
    --zone=$ZONE \
    --named-ports orders:8081,products:8082
	
gcloud compute health-checks create http fancy-fe-hc \
    --port 8080 \
    --check-interval 30s \
    --healthy-threshold 1 \
    --timeout 10s \
    --unhealthy-threshold 3
	
gcloud compute health-checks create http fancy-be-hc \
    --port 8081 \
    --request-path=/api/orders \
    --check-interval 30s \
    --healthy-threshold 1 \
    --timeout 10s \
    --unhealthy-threshold 3
	
gcloud compute firewall-rules create allow-health-check \
    --allow tcp:8080-8081 \
    --source-ranges 130.211.0.0/22,35.191.0.0/16 \
    --network default

gcloud compute instance-groups managed update fancy-fe-mig \
    --zone=$ZONE \
    --health-check fancy-fe-hc \
    --initial-delay 300
	
gcloud compute instance-groups managed update fancy-be-mig \
    --zone=$ZONE \
    --health-check fancy-be-hc \
    --initial-delay 300

read -p "Checkpoint. Press Enter to continue"
echo "Task 6 - Create load balancers"
read -p "Press enter to continue"

gcloud compute http-health-checks create fancy-fe-frontend-hc \
  --request-path / \
  --port 8080
  
gcloud compute http-health-checks create fancy-be-orders-hc \
  --request-path /api/orders \
  --port 8081
  
gcloud compute http-health-checks create fancy-be-products-hc \
  --request-path /api/products \
  --port 8082
  
gcloud compute backend-services create fancy-fe-frontend \
  --http-health-checks fancy-fe-frontend-hc \
  --port-name frontend \
  --global
  
gcloud compute backend-services create fancy-be-orders \
  --http-health-checks fancy-be-orders-hc \
  --port-name orders \
  --global
  
gcloud compute backend-services create fancy-be-products \
  --http-health-checks fancy-be-products-hc \
  --port-name products \
  --global
  
gcloud compute backend-services add-backend fancy-fe-frontend \
  --instance-group-zone=$ZONE \
  --instance-group fancy-fe-mig \
  --global
  
gcloud compute backend-services add-backend fancy-be-orders \
  --instance-group-zone=$ZONE \
  --instance-group fancy-be-mig \
  --global
  
gcloud compute backend-services add-backend fancy-be-products \
  --instance-group-zone=$ZONE \
  --instance-group fancy-be-mig \
  --global
  
gcloud compute url-maps create fancy-map \
  --default-service fancy-fe-frontend
  
gcloud compute url-maps add-path-matcher fancy-map \
   --default-service fancy-fe-frontend \
   --path-matcher-name orders \
   --path-rules "/api/orders=fancy-be-orders,/api/products=fancy-be-products"
   
gcloud compute target-http-proxies create fancy-proxy \
  --url-map fancy-map
  
gcloud compute forwarding-rules create fancy-http-rule \
  --global \
  --target-http-proxy fancy-proxy \
  --ports 80

cd ~/monolith-to-microservices/react-app/
command_output=$(gcloud compute forwarding-rules list --global)
LBUrl=$(echo "$command_output" | awk '/^IP_ADDRESS:/ { print $2 }')
sed -i "s/$backendUrl/$LBUrl/g" ~/monolith-to-microservices/react-app/.env
cd ~/monolith-to-microservices/react-app
npm install && npm run-script build
cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$DEVSHELL_PROJECT_ID/
gcloud compute instance-groups managed rolling-action replace fancy-fe-mig \
    --zone=$ZONE \
    --max-unavailable 100%

read -p "Checkpoint. Press Enter to continue"
echo "Task 7 - Scaling Compute Engine"
read -p "Press enter to continue"

gcloud compute instance-groups managed set-autoscaling \
  fancy-fe-mig \
  --zone=$ZONE \
  --max-num-replicas 2 \
  --target-load-balancing-utilization 0.60
  
gcloud compute instance-groups managed set-autoscaling \
  fancy-be-mig \
  --zone=$ZONE \
  --max-num-replicas 2 \
  --target-load-balancing-utilization 0.60
  
gcloud compute backend-services update fancy-fe-frontend \
    --enable-cdn --global

read -p "Checkpoint. Press Enter to continue"
echo "Task 8 - Update the website"
read -p "Press enter to continue"

gcloud compute instances set-machine-type frontend \
  --zone=$ZONE \
  --machine-type e2-small
  
gcloud compute instance-templates create fancy-fe-new \
    --region=$REGION \
    --source-instance=frontend \
    --source-instance-zone=$ZONE
	
gcloud compute instance-groups managed rolling-action start-update fancy-fe-mig \
  --zone=$ZONE \
  --version template=fancy-fe-new
  
cd ~/monolith-to-microservices/react-app/src/pages/Home
mv index.js.new index.js

cd ~/monolith-to-microservices/react-app
npm install && npm run-script build

cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$DEVSHELL_PROJECT_ID/

gcloud compute instance-groups managed rolling-action replace fancy-fe-mig \
  --zone=$ZONE \
  --max-unavailable=100%
  
