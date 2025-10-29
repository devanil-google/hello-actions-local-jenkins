pipeline {
    // Define an agent. This agent MUST have Docker, gcloud CLI, and git installed.
    // 'any' will pick any available agent. You might use a specific label.
    agent { any }

    // Replicates the 'workflow_dispatch' inputs
    parameters {
        stringParam(
            name: 'IMAGE_NAME_TO_SCAN',
            defaultValue: 'checkout-image',
            description: 'The tag for your application image to be built (e.g., my-app:latest)'
        )
        stringParam(
            name: 'GCP_PROJECT_ID',
            defaultValue: 'projectId',
            description: 'GCP Project ID for authentication'
        )
        stringParam(
            name: 'AR_REPOSITORY',
            defaultValue: 'images',
            description: 'Artifact Registry repository name (e.g., app-repo)'
        )
        stringParam(
            name: 'ORGANIZATION_ID',
            defaultValue: 'orgId',
            description: 'Your GCP Organization ID'
        )
        stringParam(
            name: 'CONNECTOR_ID',
            defaultValue: 'connectorId',
            description: 'The ID for your pipeline connector'
        )
        stringParam(
            name: 'SCANNER_IMAGE',
            defaultValue: 'us-central1-docker.pkg.dev/ci-plugin/ci-images/scc-artifactguard-scan-image:latest',
            description: 'The full registry path for your PRE-BUILT scanner tool'
        )
        stringParam(
            name: 'IMAGE_TAG',
            defaultValue: 'latest',
            description: 'The Docker image version (of the app image)'
        )
        booleanParam(
            name: 'IGNORE_SERVER_ERRORS',
            defaultValue: false,
            description: 'Ignore server errors'
        )
        stringParam(
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

        // Stage 2: Combines all logic from the GHA 'build-and-scan' job
        stage('Build, Scan, and Push') {
            steps {
                // This block securely provides the GCP credentials as a file
                // You must create a "Secret file" credential in Jenkins with the
                // ID 'GCP_CREDENTIALS_FILE'
                withCredentials([file(credentialsId: 'GCP_CREDENTIALS_FILE', variable: 'GCP_KEY_PATH')]) {
                    
                    // Step 2, 3, 4: Authenticate to GCP and configure Docker
                    echo "Authenticating to GCP and configuring Docker..."
                    sh "gcloud auth activate-service-account --key-file=${GCP_KEY_PATH}"
                    sh "gcloud config set project ${params.GCP_PROJECT_ID}"
                    sh "gcloud auth configure-docker us-central1-docker.pkg.dev --quiet"

                    // Step 6: Build Application Image Locally
                    echo "Building application image: ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    sh "docker build -t ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG} -f ./Dockerfile ."

                    // Step 7: Run Image Scan (inside a script block for logic)
                    echo "📦 Running Image Analysis Scan..."
                    script {
                        // Use 'returnStatus: true' to capture the exit code instead of failing the build
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
                        ) as int // Cast the status to an integer

                        echo "Docker run finished with exit code: ${scanExitCode}"

                        // Replicate the exit code logic
                        if (scanExitCode == 0) {
                            echo "✅ Evaluation succeeded: Conformant image."
                        } else if (scanExitCode == 1) {
                            echo "❌ Scan failed: Non-conformant image (vulnerabilities found)."
                            // 'error' will stop the pipeline and mark it as FAILED
                            error("Scan failed: Non-conformant image.") 
                        } else {
                            // Check the boolean parameter directly
                            if (params.IGNORE_SERVER_ERRORS) {
                                echo "⚠️ Server/internal error occurred (Code: ${scanExitCode}), but IGNORE_SERVER_ERRORS=true. Proceeding."
                            } else {
                                echo "❌ Server/internal error occurred (Code: ${scanExitCode}) during evaluation."
                                error("Scan failed: Server/internal error. Set IGNORE_SERVER_ERRORS=true to override.")
                            }
                        }
                    } // end script

                    // Step 8: Push Application Image
                    // This step will only run if the 'script' block above did not call 'error()'
                    echo "Pushing application image to Artifact Registry..."
                    script {
                        def localImage = "${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                        def remoteTag = "us-central1-docker.pkg.dev/${params.GCP_PROJECT_ID}/${params.AR_REPOSITORY}/${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"

                        echo "Tagging local image ${localImage} as ${remoteTag}"
                        sh "docker tag ${localImage} ${remoteTag}"
                        
                        echo "Pushing ${remoteTag} to Artifact Registry..."
                        sh "docker push ${remoteTag}"
                    } // end script
                    
                } // end withCredentials
            } // end steps
        } // end stage
    } // end stages
}
