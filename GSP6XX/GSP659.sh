PROJECT=$(gcloud config list project 2>/dev/null | grep = | sed "s/^[^=]*= //")

echo "Task 1 - clone repo"
read -p "Press enter to continue"
cd
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh

read -p "Checkpoint. Press Enter to continue"
echo "Task 2 - create repo and build"
read -p "Press enter to continue"

gcloud artifacts repositories create monolith-demo --repository-format=docker --location=us-central1
gcloud auth configure-docker us-central1-docker.pkg.dev
gcloud services enable artifactregistry.googleapis.com cloudbuild.googleapis.com run.googleapis.com
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag us-central1-docker.pkg.dev/$PROJECT/monolith-demo/monolith:1.0.0

read -p "Checkpoint. Press Enter to continue"
echo "Task 3 - Deploy the container to Cloud Run"
read -p "Press enter to continue"

gcloud run deploy monolith --image us-central1-docker.pkg.dev/$PROJECT/monolith-demo/monolith:1.0.0 --region us-central1

read -p "Checkpoint. Press Enter to continue"
echo "Task 4 - Create new revision with lower concurrency"
read -p "Press enter to continue"

gcloud run deploy monolith --image us-central1-docker.pkg.dev/$PROJECT/monolith-demo/monolith:1.0.0 --region us-central1 --concurrency 1

read -p "Checkpoint. Press Enter to continue"
echo "Task 5 - Make Changes To The Website"
read -p "Press enter to continue"

cd ~/monolith-to-microservices/react-app/src/pages/Home
mv index.js.new index.js
cd ~/monolith-to-microservices/react-app
npm run build:monolith
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag us-central1-docker.pkg.dev/$PROJECT/monolith-demo/monolith:2.0.0

read -p "Checkpoint. Press Enter to continue"
echo "Task 6 - Update website with zero downtime"
read -p "Press enter to continue"

gcloud run deploy monolith --image us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/monolith-demo/monolith:2.0.0 --region us-central1

read -p "Checkpoint. Press Enter to continue"
echo "All Tasks done."
read -p "Press enter to continue"
