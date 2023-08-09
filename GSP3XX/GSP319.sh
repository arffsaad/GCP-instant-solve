read -p "Input the region provided by the lab: " REGION
gcloud config set compute/region $REGION
read -p "Input the zone provided by the lab (Refer task 2): " ZONE
gcloud config set compute/zone $ZONE
GOOGLE_CLOUD_PROJECT=$(gcloud config list project 2>/dev/null | grep = | sed "s/^[^=]*= //")

cd ~
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh
gcloud services enable artifactregistry.googleapis.com cloudbuild.googleapis.com run.googleapis.com
cd ~/monolith-to-microservices/monolith
read -p "Provide the monolith image name: " monolithImg
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/$monolithImg:1.0.0 .

gcloud services enable container.googleapis.com
read -p "Provide the cluster name: " clusterName
gcloud container clusters create $clusterName --num-nodes 3
kubectl create deployment $monolithImg --image=gcr.io/$GOOGLE_CLOUD_PROJECT/$monolithImg:1.0.0
kubectl expose deployment $monolithImg --type=LoadBalancer --port 80 --target-port 8080

read -p "Provide the orders image name: " ordersName
cd ~/monolith-to-microservices/microservices/src/orders
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/$ordersName:1.0.0 .
kubectl create deployment $ordersName --image=gcr.io/$GOOGLE_CLOUD_PROJECT/$ordersName:1.0.0
kubectl expose deployment $ordersName --type=LoadBalancer --port 80 --target-port 8081
ordersIP=$(kubectl get service $ordersName -o wide --no-headers | awk '{print $4}')
read -p "Provide the products image name: " productsName
cd ~/monolith-to-microservices/microservices/src/products
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/$productsName:1.0.0 .
kubectl create deployment $productsName --image=gcr.io/$GOOGLE_CLOUD_PROJECT/$productsName:1.0.0
kubectl expose deployment $productsName --type=LoadBalancer --port 80 --target-port 8082
productsIP=$(kubectl get service $productsName -o wide --no-headers | awk '{print $4}')

sed -i "s|localhost:8081|http://$ordersIP|g" ~/monolith-to-microservices/react-app/.env
sed -i "s|localhost:8082|http://$productsIP|g" ~/monolith-to-microservices/react-app/.env
cd ~/monolith-to-microservices/react-app
npm run build

read -p "Provide the frontend image name: " feName
cd ~/monolith-to-microservices/microservices/src/frontend
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/$feName:1.0.0 .
kubectl create deployment $feName --image=gcr.io/$GOOGLE_CLOUD_PROJECT/$feName:1.0.0
kubectl expose deployment $feName --type=LoadBalancer --port 80 --target-port 8080
