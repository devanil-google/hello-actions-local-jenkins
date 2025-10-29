pipeline {
    agent any

    parameters {
        string(name: 'IMAGE_NAME_TO_SCAN', defaultValue: 'checkout-image', description: 'The tag for your application image to be built')
        string(name: 'GCP_PROJECT_ID', defaultValue: 'cispoc', description: 'GCP Project ID')
        string(name: 'AR_REPOSITORY', defaultValue: 'demo-images', description: 'Artifact Registry repository name')
        string(name: 'ORGANIZATION_ID', defaultValue: '714470867684', description: 'GCP Organization ID')
        string(name: 'CONNECTOR_ID', defaultValue: 'organizations/714470867684/locations/global/connectors/privatepreviewdemo', description: 'Pipeline connector ID')
        string(name: 'SCANNER_IMAGE', defaultValue: 'us-central1-docker.pkg.dev/ci-plugin/ci-images/scc-artifactguard-scan-image:latest', description: 'Scanner image')
        string(name: 'IMAGE_TAG', defaultValue: 'latest', description: 'Docker image tag')
        booleanParam(name: 'IGNORE_SERVER_ERRORS', defaultValue: false, description: 'Ignore server errors')
        string(name: 'VERBOSITY', defaultValue: 'HIGH', description: 'Verbosity flag')
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    def start = System.currentTimeMillis()
                    echo "📦 Checking out source code..."
                    checkout scm
                    def end = System.currentTimeMillis()
                    writeFile file: 'latencies.txt', text: "Checkout:${end - start}\n", append: true
                }
            }
        }

        stage('Build Application Image') {
            steps {
                script {
                    def start = System.currentTimeMillis()
                    echo "📦 Building image: ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    sh "docker build -t ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG} -f ./Dockerfile ."
                    def end = System.currentTimeMillis()
                    writeFile file: 'latencies.txt', text: "Build:${end - start}\n", append: true
                }
            }
        }

        stage('Authenticate to GCP') {
            steps {
                script {
                    def start = System.currentTimeMillis()
                    withCredentials([file(credentialsId: 'GCP_CREDENTIALS', variable: 'GCP_KEY_FILE')]) {
                        sh "gcloud auth activate-service-account --key-file=\"$GCP_KEY_FILE\""
                        sh 'gcloud auth list'
                        sh 'gcloud auth configure-docker gcr.io --quiet'
                        sh 'gcloud auth configure-docker us-central1-docker.pkg.dev --quiet'

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
                            error("❌ Scan failed: Non-conformant image.")
                        } else {
                            if (params.IGNORE_SERVER_ERRORS) {
                                echo "⚠️ Server/internal error occurred, but IGNORE_SERVER_ERRORS=true."
                            } else {
                                error("❌ Server/internal error during evaluation.")
                            }
                        }
                    }
                    def end = System.currentTimeMillis()
                    writeFile file: 'latencies.txt', text: "Authenticate:${end - start}\n", append: true
                }
            }
        }

        stage('Push Application Image') {
            steps {
                script {
                    def start = System.currentTimeMillis()
                    def localImage = "${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    def remoteTag = "us-central1-docker.pkg.dev/${params.GCP_PROJECT_ID}/${params.AR_REPOSITORY}/${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    echo "Tagging local image ${localImage} as ${remoteTag}"
                    sh "docker tag ${localImage} ${remoteTag}"
                    echo "Pushing ${remoteTag} to Artifact Registry..."
                    sh "docker push ${remoteTag}"
                    def end = System.currentTimeMillis()
                    writeFile file: 'latencies.txt', text: "Push:${end - start}\n", append: true
                }
            }
        }
    }

    post {
        always {
            script {
                // Read stage durations
                def stages = []
                def durations = []
                readFile('latencies.txt').split('\n').each { line ->
                    if (line) {
                        def (name, time) = line.split(':')
                        stages << name
                        durations << time.toInteger()
                    }
                }

                // Create HTML with Chart.js
                def html = """
                <html>
                <head>
                    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
                </head>
                <body>
                    <h2>Pipeline Latency Report - Build #${env.BUILD_NUMBER}</h2>
                    <canvas id="latencyChart"></canvas>
                    <script>
                        const ctx = document.getElementById('latencyChart').getContext('2d');
                        new Chart(ctx, {
                            type: 'bar',
                            data: {
                                labels: ${stages},
                                datasets: [{ label: 'Duration (ms)', data: ${durations} }]
                            },
                            options: {
                                scales: { y: { beginAtZero: true } }
                            }
                        });
                    </script>
                </body>
                </html>
                """
                writeFile file: 'latency-report.html', text: html

                // Publish the HTML report
                publishHTML([
                    reportDir: '.',
                    reportFiles: 'latency-report.html',
                    reportName: 'Pipeline Latency Report',
                    keepAll: true
                ])
            }
        }
    }
}
