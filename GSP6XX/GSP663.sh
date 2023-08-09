gcloud config set compute/zone us-central1-f
gcloud services enable container.googleapis.com
gcloud container clusters create fancy-cluster --num-nodes 3
GOOGLE_CLOUD_PROJECT=$(gcloud config list project 2>/dev/null | grep = | sed "s/^[^=]*= //")

read -p "Checkpoint. Press Enter to continue"

cd ~
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh
nvm install --lts
gcloud services enable cloudbuild.googleapis.com
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/monolith:1.0.0 .

read -p "Checkpoint. Press Enter to continue"

kubectl create deployment monolith --image=gcr.io/$GOOGLE_CLOUD_PROJECT/monolith:1.0.0

read -p "Checkpoint. Press Enter to continue"

kubectl expose deployment monolith --type=LoadBalancer --port 80 --target-port 8080

read -p "Checkpoint. Press Enter to continue"

kubectl scale deployment monolith --replicas=3

read -p "Checkpoint. Press Enter to continue"

cd ~/monolith-to-microservices/react-app/src/pages/Home
mv index.js.new index.js
cd ~/monolith-to-microservices/react-app
npm run build:monolith
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/$GOOGLE_CLOUD_PROJECT/monolith:2.0.0 .

read -p "Checkpoint. Press Enter to continue"

kubectl set image deployment/monolith monolith=gcr.io/$GOOGLE_CLOUD_PROJECT/monolith:2.0.0
