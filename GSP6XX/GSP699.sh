read -p "Input the zone provided by the lab: " ZONE
gcloud config set compute/zone $ZONE
GOOGLE_CLOUD_PROJECT=$(gcloud config list project 2>/dev/null | grep = | sed "s/^[^=]*= //")

read -p "Checkpoint. Press Enter to continue"

cd ~
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh

read -p "Checkpoint. Press Enter to continue"

gcloud services enable container.googleapis.com
gcloud container clusters create fancy-cluster --num-nodes 3 --machine-type=e2-standard-4

read -p "Checkpoint. Press Enter to continue"

cd ~/monolith-to-microservices
./deploy-monolith.sh

read -p "Checkpoint. Press Enter to continue"

cd ~/monolith-to-microservices/microservices/src/orders
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/orders:1.0.0 .
kubectl create deployment orders --image=gcr.io/$GOOGLE_CLOUD_PROJECT/orders:1.0.0
kubectl expose deployment orders --type=LoadBalancer --port 80 --target-port 8081
ordersIP=$(kubectl get service orders -o wide --no-headers | awk '{print $4}')
sed -i "s|/service/orders|http://$ordersIP/api/orders|g" ~/monolith-to-microservices/react-app/.env.monolith
cd ~/monolith-to-microservices/react-app
npm run build:monolith
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/monolith:2.0.0 .
kubectl set image deployment/monolith monolith=gcr.io/$GOOGLE_CLOUD_PROJECT/monolith:2.0.0

read -p "Checkpoint. Press Enter to continue"

cd ~/monolith-to-microservices/microservices/src/products
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/products:1.0.0 .
kubectl create deployment products --image=gcr.io/$GOOGLE_CLOUD_PROJECT/products:1.0.0
kubectl expose deployment products --type=LoadBalancer --port 80 --target-port 8082
productsIP=$(kubectl get service products -o wide --no-headers | awk '{print $4}')
sed -i "s|/service/products|http://$productsIP/api/products|g" ~/monolith-to-microservices/react-app/.env.monolith
cd ~/monolith-to-microservices/react-app
npm run build:monolith
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/monolith:3.0.0 .
kubectl set image deployment/monolith monolith=gcr.io/$GOOGLE_CLOUD_PROJECT/monolith:3.0.0

read -p "Checkpoint. Press Enter to continue"

cd ~/monolith-to-microservices/react-app
cp .env.monolith .env
npm run build
cd ~/monolith-to-microservices/microservices/src/frontend
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/frontend:1.0.0 .
kubectl create deployment frontend --image=gcr.io/$GOOGLE_CLOUD_PROJECT/frontend:1.0.0
kubectl expose deployment frontend --type=LoadBalancer --port 80 --target-port 8080
