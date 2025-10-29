pipeline {
    agent any

    // Replicates the 'workflow_dispatch' inputs
    parameters {
        string(
            name: 'IMAGE_NAME_TO_SCAN',
            defaultValue: 'checkout-image',
            description: 'The tag for your application image to be built (e.g., my-app:latest)'
        )
        string(
            name: 'GCP_PROJECT_ID',
            defaultValue: 'projectId',
            description: 'GCP Project ID for authentication'
        )
        string(
            name: 'AR_REPOSITORY',
            defaultValue: 'images',
            description: 'Artifact Registry repository name (e.g., app-repo)'
        )
        string(
            name: 'ORGANIZATION_ID',
            defaultValue: 'orgId',
            description: 'Your GCP Organization ID'
        )
        string(
            name: 'CONNECTOR_ID',
            defaultValue: 'connectorId',
            description: 'The ID for your pipeline connector'
        )
        string(
            name: 'SCANNER_IMAGE',
            defaultValue: 'us-central1-docker.pkg.dev/ci-plugin/ci-images/scc-artifactguard-scan-image:latest',
            description: 'The full registry path for your PRE-BUILT scanner tool'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: 'latest',
            description: 'The Docker image version (of the app image)'
        )
        booleanParam(
            name: 'IGNORE_SERVER_ERRORS',
            defaultValue: false,
            description: 'Ignore server errors'
        )
        string(
            name: 'VERBOSITY',
            defaultValue: 'HIGH',
            description: 'Verbosity flag'
        )
    }

    stages {
        // Stage 1: Check out the source code
        stage('Checkout') {
            steps {
                echo "Checking out source code..."
                checkout scm
            }
        }

        // Stage 2: Build, Scan, and Push
        stage('Build, Scan, and Push') {
            steps {
                withCredentials([file(credentialsId: 'GCP_CREDENTIALS_FILE', variable: 'GCP_KEY_PATH')]) {

                    // Authenticate to GCP and configure Docker
                    echo "Authenticating to GCP and configuring Docker..."
                    sh "gcloud auth activate-service-account --key-file=${GCP_KEY_PATH}"
                    sh "gcloud config set project ${params.GCP_PROJECT_ID}"
                    sh "gcloud auth configure-docker us-central1-docker.pkg.dev --quiet"

                    // Build Application Image
                    echo "Building application image: ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    sh "docker build -t ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG} -f ./Dockerfile ."

                    // Run Image Scan
                    echo "📦 Running Image Analysis Scan..."
                    script {
                        def scanExitCode = sh(
                            script: """
                                docker run --rm \
                                  -v /var/run/docker.sock:/var/run/docker.sock \
                                  -v ${GCP_KEY_PATH}:/tmp/scc-key.json \
                                  -e GCLOUD_KEY_PATH=/tmp/scc-key.json \
                                  -e GCP_PROJECT_ID="${params.GCP_PROJECT_ID}" \
                                  -e ORGANIZATION_ID="${params.ORGANIZATION_ID}" \
                                  -e IMAGE_NAME="${params.IMAGE_NAME_TO_SCAN}" \
                                  -e IMAGE_TAG="${params.IMAGE_TAG}" \
                                  -e CONNECTOR_ID="${params.CONNECTOR_ID}" \
                                  -e BUILD_TAG="${env.JOB_NAME}" \
                                  -e BUILD_ID="${env.BUILD_NUMBER}" \
                                  -e VERBOSITY="${params.VERBOSITY}" \
                                  "${params.SCANNER_IMAGE}"
                            """,
                            returnStatus: true
                        ) as int

                        echo "Docker run finished with exit code: ${scanExitCode}"

                        if (scanExitCode == 0) {
                            echo "✅ Evaluation succeeded: Conformant image."
                        } else if (scanExitCode == 1) {
                            echo "❌ Scan failed: Non-conformant image (vulnerabilities found)."
                            error("Scan failed: Non-conformant image.") 
                        } else {
                            if (params.IGNORE_SERVER_ERRORS) {
                                echo "⚠️ Server/internal error occurred (Code: ${scanExitCode}), but IGNORE_SERVER_ERRORS=true. Proceeding."
                            } else {
                                echo "❌ Server/internal error occurred (Code: ${scanExitCode}) during evaluation."
                                error("Scan failed: Server/internal error. Set IGNORE_SERVER_ERRORS=true to override.")
                            }
                        }
                    }

                    // Push Application Image
                    echo "Pushing application image to Artifact Registry..."
                    script {
                        def localImage = "${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                        def remoteTag = "us-central1-docker.pkg.dev/${params.GCP_PROJECT_ID}/${params.AR_REPOSITORY}/${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"

                        echo "Tagging local image ${localImage} as ${remoteTag}"
                        sh "docker tag ${localImage} ${remoteTag}"
                        
                        echo "Pushing ${remoteTag} to Artifact Registry..."
                        sh "docker push ${remoteTag}"
                    }

                }
            }
        }
    }
}
