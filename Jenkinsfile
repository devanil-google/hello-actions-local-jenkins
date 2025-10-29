import groovy.transform.Field

@Field Map<String, Long> latencyData = [:] // global map for stage latencies

pipeline {
    agent any

    parameters {
        string(name: 'IMAGE_NAME_TO_SCAN', defaultValue: 'checkout-image', description: 'The tag for your application image to be built (e.g., my-app:latest)')
        string(name: 'GCP_PROJECT_ID', defaultValue: 'cispoc', description: 'GCP Project ID for authentication')
        string(name: 'AR_REPOSITORY', defaultValue: 'demo-images', description: 'Artifact Registry repository name (e.g., app-repo)')
        string(name: 'ORGANIZATION_ID', defaultValue: '714470867684', description: 'Your GCP Organization ID')
        string(name: 'CONNECTOR_ID', defaultValue: 'organizations/714470867684/locations/global/connectors/privatepreviewdemo', description: 'The ID for your pipeline connector')
        string(name: 'SCANNER_IMAGE', defaultValue: 'us-central1-docker.pkg.dev/ci-plugin/ci-images/scc-artifactguard-scan-image:latest', description: 'The full registry path for your PRE-BUILT scanner tool')
        string(name: 'IMAGE_TAG', defaultValue: 'latest', description: 'The Docker image version (of the app image)')
        booleanParam(name: 'IGNORE_SERVER_ERRORS', defaultValue: false, description: 'Ignore server errors')
        string(name: 'VERBOSITY', defaultValue: 'HIGH', description: 'Verbosity flag')
    }

    environment {
        REPORT_FILE = "latency-report.html"
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    long stageStart = System.currentTimeMillis()
                    echo "📦 Checking out source code..."
                    checkout scm
                    long stageEnd = System.currentTimeMillis()
                    latencyData['Checkout'] = stageEnd - stageStart
                }
            }
        }

        stage('Build Application Image') {
            steps {
                script {
                    long stageStart = System.currentTimeMillis()
                    echo "🔨 Building application image: ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    sh "docker build -t ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG} -f ./Dockerfile ."
                    long stageEnd = System.currentTimeMillis()
                    latencyData['Build Application Image'] = stageEnd - stageStart
                }
            }
        }

        stage('Authenticate to GCP') {
            steps {
                script {
                    long stageStart = System.currentTimeMillis()

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

                    long stageEnd = System.currentTimeMillis()
                    latencyData['Authenticate to GCP'] = stageEnd - stageStart
                }
            }
        }

        stage('Push Application Image') {
            steps {
                script {
                    long stageStart = System.currentTimeMillis()

                    def localImage = "${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    def remoteTag = "us-central1-docker.pkg.dev/${params.GCP_PROJECT_ID}/${params.AR_REPOSITORY}/${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"

                    echo "Tagging local image ${localImage} as ${remoteTag}"
                    sh "docker tag ${localImage} ${remoteTag}"

                    echo "Pushing ${remoteTag} to Artifact Registry..."
                    sh "docker push ${remoteTag}"

                    long stageEnd = System.currentTimeMillis()
                    latencyData['Push Application Image'] = stageEnd - stageStart
                }
            }
        }
    }

    post {
        always {
            script {
                echo "Latencies: ${latencyData}"

                // Generate HTML report with Chart.js
                def html = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <title>Pipeline Latency Report</title>
                    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
                    <style>
                        body { font-family: Arial; padding: 20px; background: #f5f5f5; }
                        canvas { background: #fff; border: 1px solid #ccc; padding: 10px; }
                    </style>
                </head>
                <body>
                    <h2>Pipeline Latency Report - Build #${env.BUILD_NUMBER}</h2>
                    <canvas id="latencyChart" width="800" height="400"></canvas>
                    <script>
                        const ctx = document.getElementById('latencyChart').getContext('2d');
                        new Chart(ctx, {
                            type: 'bar',
                            data: {
                                labels: ${latencyData.keySet() as List},
                                datasets: [{
                                    label: 'Stage Duration (ms)',
                                    data: ${latencyData.values() as List},
                                    backgroundColor: 'rgba(54, 162, 235, 0.6)',
                                    borderColor: 'rgba(54, 162, 235, 1)',
                                    borderWidth: 1
                                }]
                            },
                            options: { scales: { y: { beginAtZero: true } } }
                        });
                    </script>
                </body>
                </html>
                """

                writeFile file: env.REPORT_FILE, text: html

                // Publish HTML report in Jenkins
                publishHTML([
                    reportDir: '.',
                    reportFiles: env.REPORT_FILE,
                    reportName: 'Latency Report',
                    keepAll: true
                ])
            }
        }
    }
}
