pipeline {
    agent any

    parameters {
        string(name: 'IMAGE_NAME_TO_SCAN', defaultValue: 'checkout-image', description: 'App image name')
        string(name: 'GCP_PROJECT_ID', defaultValue: 'cispoc', description: 'GCP Project ID')
        string(name: 'AR_REPOSITORY', defaultValue: 'demo-images', description: 'Artifact Registry repo')
        string(name: 'ORGANIZATION_ID', defaultValue: '714470867684', description: 'GCP Org ID')
        string(name: 'CONNECTOR_ID', defaultValue: 'organizations/714470867684/locations/global/connectors/privatepreviewdemo', description: 'Connector ID')
        string(name: 'SCANNER_IMAGE', defaultValue: 'us-central1-docker.pkg.dev/ci-plugin/ci-images/scc-artifactguard-scan-image:latest', description: 'Scanner image path')
        string(name: 'IMAGE_TAG', defaultValue: 'latest', description: 'Image tag')
        booleanParam(name: 'IGNORE_SERVER_ERRORS', defaultValue: false, description: 'Ignore server errors')
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    def startTime = System.currentTimeMillis()
                    echo "📦 Checking out source code..."
                    checkout scm
                    def endTime = System.currentTimeMillis()
                    currentBuild.description = "Pipeline started"
                    currentBuild.rawBuild.setAction(new hudson.model.ParametersAction())
                    // store times in build vars
                    currentBuild.buildVariables['CHECKOUT_END'] = endTime.toString()
                    currentBuild.buildVariables['START_TIME'] = startTime.toString()
                }
            }
        }

        stage('Build Application Image') {
            steps {
                script {
                    def checkoutEnd = currentBuild.buildVariables['CHECKOUT_END'] as long
                    def startTime = System.currentTimeMillis()
                    def latency = (startTime - checkoutEnd) / 1000.0
                    echo "\n⏱️ Latency since Checkout: ${String.format('%.2f', latency)}s\n"

                    echo "🏗️ Building application image..."
                    sh "docker build -t ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG} -f ./Dockerfile ."

                    def duration = (System.currentTimeMillis() - startTime) / 1000.0
                    currentBuild.buildVariables['BUILD_END'] = System.currentTimeMillis().toString()
                    currentBuild.buildVariables['LAT_BUILD'] = latency.toString()
                    currentBuild.buildVariables['DUR_BUILD'] = duration.toString()
                }
            }
        }

        stage('Authenticate to GCP') {
            steps {
                script {
                    def buildEnd = currentBuild.buildVariables['BUILD_END'] as long
                    def startTime = System.currentTimeMillis()
                    def latency = (startTime - buildEnd) / 1000.0
                    echo "\n🌐 Latency since Build Application Image: ${String.format('%.2f', latency)}s\n"

                    withCredentials([file(credentialsId: 'GCP_CREDENTIALS', variable: 'GCP_KEY_FILE')]) {
                        sh "gcloud auth activate-service-account --key-file=\"$GCP_KEY_FILE\""
                        sh 'gcloud auth list'
                        sh 'gcloud auth configure-docker gcr.io --quiet'
                        sh 'gcloud auth configure-docker us-central1-docker.pkg.dev --quiet'

                        echo "🔍 Running scanner container: ${params.SCANNER_IMAGE}"
                        def exitCode = sh(script: """
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
                        """, returnStatus: true)

                        if (exitCode == 0) echo "✅ Evaluation succeeded."
                        else if (exitCode == 1) error("❌ Non-conformant image.")
                        else if (!params.IGNORE_SERVER_ERRORS) error("❌ Internal error during evaluation.")
                        else echo "⚠️ Server error ignored."
                    }

                    def duration = (System.currentTimeMillis() - startTime) / 1000.0
                    currentBuild.buildVariables['AUTH_END'] = System.currentTimeMillis().toString()
                    currentBuild.buildVariables['LAT_AUTH'] = latency.toString()
                    currentBuild.buildVariables['DUR_AUTH'] = duration.toString()
                }
            }
        }

        stage('Push Application Image') {
            steps {
                script {
                    def authEnd = currentBuild.buildVariables['AUTH_END'] as long
                    def startTime = System.currentTimeMillis()
                    def latency = (startTime - authEnd) / 1000.0
                    echo "\n🚀 Latency since Authenticate to GCP: ${String.format('%.2f', latency)}s\n"

                    def localImage = "${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    def remoteTag = "us-central1-docker.pkg.dev/${params.GCP_PROJECT_ID}/${params.AR_REPOSITORY}/${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    sh "docker tag ${localImage} ${remoteTag}"
                    sh "docker push ${remoteTag}"

                    def duration = (System.currentTimeMillis() - startTime) / 1000.0
                    currentBuild.buildVariables['PUSH_END'] = System.currentTimeMillis().toString()
                    currentBuild.buildVariables['LAT_PUSH'] = latency.toString()
                    currentBuild.buildVariables['DUR_PUSH'] = duration.toString()
                }
            }
        }
    }

    post {
        always {
            script {
                def start = currentBuild.buildVariables['START_TIME'] as long
                def end = currentBuild.buildVariables['PUSH_END'] as long
                def total = (end - start) / 1000.0

                def latencies = [
                    (currentBuild.buildVariables['LAT_BUILD'] ?: "0") as double,
                    (currentBuild.buildVariables['LAT_AUTH'] ?: "0") as double,
                    (currentBuild.buildVariables['LAT_PUSH'] ?: "0") as double
                ]
                def durations = [
                    (currentBuild.buildVariables['DUR_BUILD'] ?: "0") as double,
                    (currentBuild.buildVariables['DUR_AUTH'] ?: "0") as double,
                    (currentBuild.buildVariables['DUR_PUSH'] ?: "0") as double
                ]

                // Build fancy HTML report
                def html = """
<!DOCTYPE html>
<html>
<head>
  <meta charset='UTF-8'>
  <title>Jenkins Latency Report</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    body { font-family: 'Segoe UI', sans-serif; background: #f7fafc; color: #2d3748; margin: 40px; }
    h1 { color: #2b6cb0; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; background: white; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
    th, td { padding: 12px 16px; border-bottom: 1px solid #eee; text-align: left; }
    th { background: #2b6cb0; color: white; }
    .chart-container { margin: 30px auto; width: 80%; background: white; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); padding: 20px; }
  </style>
</head>
<body>
  <h1>📊 Jenkins Latency & Duration Report</h1>
  <p><strong>Build #${env.BUILD_NUMBER}</strong> — ${new Date()}<br>
  Total Pipeline Duration: <strong>${String.format('%.2f', total)}s</strong></p>

  <h2>Stage Summary</h2>
  <table>
    <thead><tr><th>Stage</th><th>Duration (s)</th><th>Latency (s)</th></tr></thead>
    <tbody>
      <tr><td>🏗️ Build</td><td>${String.format('%.2f', durations[0])}</td><td>${String.format('%.2f', latencies[0])}</td></tr>
      <tr><td>🌐 Authenticate</td><td>${String.format('%.2f', durations[1])}</td><td>${String.format('%.2f', latencies[1])}</td></tr>
      <tr><td>🚀 Push</td><td>${String.format('%.2f', durations[2])}</td><td>${String.format('%.2f', latencies[2])}</td></tr>
    </tbody>
  </table>

  <div class='chart-container'>
    <h2>📈 Latency Between Stages</h2>
    <canvas id='latencyChart'></canvas>
  </div>

  <div class='chart-container'>
    <h2>⚙️ Stage Durations</h2>
    <canvas id='durationChart'></canvas>
  </div>

  <script>
    new Chart(document.getElementById('latencyChart'), {
      type: 'bar',
      data: {
        labels: ['Checkout→Build','Build→Auth','Auth→Push'],
        datasets: [{ label: 'Latency (s)', data: ${latencies}, backgroundColor: ['#63b3ed','#fc8181','#ed8936'] }]
      },
      options: { scales: { y: { beginAtZero: true } } }
    });

    new Chart(document.getElementById('durationChart'), {
      type: 'bar',
      data: {
        labels: ['Build','Auth','Push'],
        datasets: [{ label: 'Duration (s)', data: ${durations}, backgroundColor: ['#48bb78','#4299e1','#ed8936'] }]
      },
      options: { scales: { y: { beginAtZero: true } } }
    });
  </script>
</body>
</html>
"""
                writeFile file: 'latency-report.html', text: html
                publishHTML([reportDir: '.', reportFiles: 'latency-report.html', reportName: 'Latency Report', keepAll: true])
            }
        }
    }
}
