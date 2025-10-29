import groovy.transform.Field
@Field def stageTimings = [:]   // Make this variable global to the script

pipeline {
    agent any

    options {
        timestamps()
    }
    
    parameters {
        string(
            name: 'IMAGE_NAME_TO_SCAN',
            defaultValue: 'checkout-image',
            description: 'The tag for your application image to be built (e.g., my-app:latest)'
        )
        string(
            name: 'GCP_PROJECT_ID',
            defaultValue: 'cispoc',
            description: 'GCP Project ID for authentication'
        )
        string(
            name: 'AR_REPOSITORY',
            defaultValue: 'demo-images',
            description: 'Artifact Registry repository name (e.g., app-repo)'
        )
        string(
            name: 'ORGANIZATION_ID',
            defaultValue: '714470867684',
            description: 'Your GCP Organization ID'
        )
        string(
            name: 'CONNECTOR_ID',
            defaultValue: 'organizations/714470867684/locations/global/connectors/privatepreviewdemo',
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
                script {
                    def startTime = System.currentTimeMillis()
                    try {
                        echo "Checking out source code..."
                        checkout scm
                    } finally {
                        def endTime = System.currentTimeMillis()
                        def duration = (endTime - startTime) / 1000.0
                        this.stageTimings['Checkout'] = duration // Use 'this.' to access global variable
                        echo "Checkout stage finished. Took: ${duration}s"
                    }
                }
            }
        }

        // Stage 2: Build application image
        stage('Build Application Image') {
            steps {
                script {
                    def startTime = System.currentTimeMillis()
                    try {
                        echo "Building application image: ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                        sh "docker build -t ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG} -f ./Dockerfile ."
                    } finally {
                        def endTime = System.currentTimeMillis()
                        def duration = (endTime - startTime) / 1000.0
                        this.stageTimings['Build'] = duration // Use 'this.'
                        echo "Build stage finished. Took: ${duration}s"
                    }
                }
            }
        }

        // Stage 3: Authenticate to GCP and run scanner
        stage('Authenticate & Scan') {
            steps {
                script {
                    def startTime = System.currentTimeMillis()
                    try {
                        withCredentials([file(credentialsId: 'GCP_CREDENTIALS', variable: 'GCP_KEY_FILE')]) {
                            // Authenticate
                            sh "gcloud auth activate-service-account --key-file=\"$GCP_KEY_FILE\""
                            sh 'gcloud auth list'
                            sh 'gcloud auth configure-docker gcr.io --quiet'
                            sh 'gcloud auth configure-docker us-central1-docker.pkg.dev --quiet'

                            // Run scanner container
                            def exitCode = sh(
                                script: """
                                    echo "📦 Running scanner container from image: ${params.SCANNER_IMAGE}"
                                    docker run --rm \\
                                        -v /var/run/docker.sock:/var/run/docker.sock \\
                                        -v "$GCP_KEY_FILE":/tmp/scc-key.json \\
                                        -e GCLOUD_KEY_PATH=/tmp/scc-key.json \\
                                        -e GCP_PROJECT_ID="${params.GCP_PROJECT_ID}" \\
                                        -e ORGANIZATION_ID="${params.ORGANIZATION_ID}" \\
                                        -e IMAGE_NAME="${params.IMAGE_NAME_TO_SCAN}" \\
                                        -e IMAGE_TAG="${params.IMAGE_TAG}" \\
                                        -e CONNECTOR_ID="${params.CONNECTOR_ID}" \\
                                        -e BUILD_TAG="${env.JOB_NAME}" \\
                                        -e BUILD_ID="${env.BUILD_NUMBER}" \\
                                        "${params.SCANNER_IMAGE}"
                                """,
                                returnStatus: true
                            )

                            if (exitCode == 0) {
                                echo "✅ Evaluation succeeded: Conformant image."
                            } else if (exitCode == 1) {
                                error("❌ Scan failed: Non-conformant image (vulnerabilities found).")
                            } else {
                                if (params.IGNORE_SERVER_ERRORS) {
                                    echo "⚠️ Server/internal error occurred, but IGNORE_SERVER_ERRORS=true. Proceeding with pipeline."
                                } else {
                                    error("❌ Server/internal error occurred during evaluation. Set IGNORE_SERVER_ERRORS=true to override.")
                                }
                            }
                        }
                    } finally {
                        def endTime = System.currentTimeMillis()
                        def duration = (endTime - startTime) / 1000.0
                        this.stageTimings['Scan'] = duration // Use 'this.'
                        echo "Authenticate & Scan stage finished. Took: ${duration}s"
                    }
                }
            }
        }

        // Stage 4: Push Application Image
        stage('Push Application Image') {
            steps {
                script {
                    def startTime = System.currentTimeMillis()
                    try {
                        def localImage = "${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                        def remoteTag = "us-central1-docker.pkg.dev/${params.GCP_PROJECT_ID}/${params.AR_REPOSITORY}/${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"

                        echo "Tagging local image ${localImage} as ${remoteTag}"
                        sh "docker tag ${localImage} ${remoteTag}"
                        
                        echo "Pushing ${remoteTag} to Artifact Registry..."
                        sh "docker push ${remoteTag}"
                    } finally {
                        def endTime = System.currentTimeMillis()
                        def duration = (endTime - startTime) / 1000.0
                        this.stageTimings['Push'] = duration // Use 'this.'
                        echo "Push stage finished. Took: ${duration}s"
                    }
                }
            }
        }

        // --- NEW FINAL STAGE TO PRINT RESULTS ---
        stage('Print Latencies') {
            // This stage will always run, even if previous stages failed
            when { expression { true } }
            steps {
                script {
                    echo "--- 📊 Final Pipeline Latencies ---"
                    echo "${this.stageTimings}"
                    echo "------------------------------------"
                }
            }
        }
    }

    // --- REMOVED THE ENTIRE 'post' BLOCK ---
}
