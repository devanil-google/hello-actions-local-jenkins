import groovy.transform.Field
@Field def stageTimings = [:]   // <-- FIX 1: Make this variable global to the script

pipeline {
    agent any

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
                        this.stageTimings['Checkout'] = duration // <-- FIX 2: Use 'this.' to access global variable
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
                        this.stageTimings['Build'] = duration // <-- FIX 2: Use 'this.'
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
                                        -v "$GGCP_KEY_FILE":/tmp/scc-key.json \\
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
                        this.stageTimings['Scan'] = duration // <-- FIX 2: Use 'this.'
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
                        this.stageTimings['Push'] = duration // <-- FIX 2: Use 'this.'
                        echo "Push stage finished. Took: ${duration}s"
                    }
                }
            }
        }
    }

    // --- POST-BUILD STEP (Unchanged) ---
    post {
        always {
            script {
                echo "📊 Generating latency report..."
                echo "Raw timing data: ${this.stageTimings}" // Using 'this.' here too for consistency

                // Generate JavaScript arrays from our Groovy map
                def labels = this.stageTimings.collect { key, val -> "'${key}'" }.join(',')
                def data = this.stageTimings.collect { key, val -> val }.join(',')

                // Define the HTML content for the report
                def htmlContent = """
                <html>
                <head>
                    <title>Pipeline Latency Report</title>
                    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
                    <style>
                        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
                        .chart-container { 
                            width: 80%; 
                            max-width: 900px; 
                            margin: auto; 
                            padding: 20px; 
                            border: 1px solid #ddd; 
                            border-radius: 8px; 
                            box-shadow: 0 4px 12px rgba(0,0,0,0.05);
                        }
                    </style>
                </head>
                <body>
                    <div class="chart-container">
                        <h2>Pipeline Stage Latency (Build #${env.BUILD_NUMBER})</h2>
                        <canvas id="latencyChart"></canvas>
                    </div>
                    <script>
                        const ctx = document.getElementById('latencyChart').getContext('2d');
                        new Chart(ctx, {
                            type: 'bar',
                            data: {
                                labels: [${labels}],
                                datasets: [{
                                    label: 'Stage Duration (seconds)',
                                    data: [${data}],
                                    backgroundColor: [
                                        'rgba(54, 162, 235, 0.2)',
                                        'rgba(255, 206, 86, 0.2)',
                                        'rgba(255, 99, 132, 0.2)',
                                        'rgba(75, 192, 192, 0.2)',
                                        'rgba(153, 102, 255, 0.2)'
                                    ],
                                    borderColor: [
                                        'rgba(54, 162, 235, 1)',
                                        'rgba(255, 206, 86, 1)',
                                        'rgba(255, 99, 132, 1)',
                                        'rgba(75, 192, 192, 1)',
                                        'rgba(153, 102, 255, 1)'
                                    ],
                                    borderWidth: 1
                                }]
                            },
                            options: {
                                indexAxis: 'y', // Makes it a horizontal bar chart for readability
                                scales: {
                                    x: {
                                        beginAtZero: true,
                                        title: {
                                            display: true,
                                            text: 'Duration (seconds)'
                                        }
                                    }
                                }
                            }
                        });
                    </script>
                </body>
                </html>
                """
                
                // Write the HTML to a file in the workspace
                writeFile file: 'latency-report.html', text: htmlContent

                // Publish the HTML report
                publishHTML(target: [
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: '.',
                    reportFiles: 'latency-report.html',
                    reportName: 'Latency Report'
                ])
            }
        }
    }
}
