pipeline {
    agent any

    parameters {
        string(name: 'IMAGE_NAME_TO_SCAN', defaultValue: 'checkout-image', description: 'The tag for your application image')
        string(name: 'GCP_PROJECT_ID', defaultValue: 'cispoc', description: 'GCP Project ID for authentication')
        string(name: 'AR_REPOSITORY', defaultValue: 'demo-images', description: 'Artifact Registry repository name')
        string(name: 'ORGANIZATION_ID', defaultValue: '714470867684', description: 'Your GCP Organization ID')
        string(name: 'CONNECTOR_ID', defaultValue: 'organizations/714470867684/locations/global/connectors/privatepreviewdemo', description: 'The ID for your pipeline connector')
        string(name: 'SCANNER_IMAGE', defaultValue: 'us-central1-docker.pkg.dev/ci-plugin/ci-images/scc-artifactguard-scan-image:latest', description: 'The full registry path for your PRE-BUILT scanner tool')
        string(name: 'IMAGE_TAG', defaultValue: 'latest', description: 'Docker image version')
        booleanParam(name: 'IGNORE_SERVER_ERRORS', defaultValue: false, description: 'Ignore server errors')
        string(name: 'VERBOSITY', defaultValue: 'HIGH', description: 'Verbosity flag')
    }

    environment {
        START_TIME = ""
        LAST_STAGE_END = ""
        LATENCY_LOG = ""
        LATENCY_DATA = ""
        DURATION_DATA = ""
        STAGES_JSON = ""
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    START_TIME = System.currentTimeMillis()
                    echo "📦 Checking out source code..."
                    checkout scm
                    LAST_STAGE_END = System.currentTimeMillis()
                }
            }
        }

        stage('Build Application Image') {
            steps {
                script {
                    def now = System.currentTimeMillis()
                    def latency = (now - LAST_STAGE_END.toLong()) / 1000.0
                    def stageStart = now
                    echo "\n⏱️  Latency since *Checkout*: ${String.format('%.2f', latency)}s\n"
                    LATENCY_LOG += "Checkout ➜ Build Application Image: ${String.format('%.2f', latency)}s\n"

                    echo "🏗️ Building application image..."
                    sh "docker build -t ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG} -f ./Dockerfile ."

                    def duration = (System.currentTimeMillis() - stageStart) / 1000.0
                    DURATION_DATA += "${duration},"
                    LATENCY_DATA += "${latency},"
                    STAGES_JSON += "'Build Application Image',"
                    LAST_STAGE_END = System.currentTimeMillis()
                }
            }
        }

        stage('Authenticate to GCP') {
            steps {
                script {
                    def now = System.currentTimeMillis()
                    def latency = (now - LAST_STAGE_END.toLong()) / 1000.0
                    def stageStart = now
                    echo "\n🌐 Latency since *Build Application Image*: ${String.format('%.2f', latency)}s\n"
                    LATENCY_LOG += "Build Application Image ➜ Authenticate to GCP: ${String.format('%.2f', latency)}s\n"

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

                        if (exitCode == 0) {
                            echo "✅ Evaluation succeeded."
                        } else if (exitCode == 1) {
                            error("❌ Non-conformant image (vulnerabilities found).")
                        } else {
                            if (params.IGNORE_SERVER_ERRORS) {
                                echo "⚠️ Server/internal error, continuing."
                            } else {
                                error("❌ Server/internal error during evaluation.")
                            }
                        }
                    }

                    def duration = (System.currentTimeMillis() - stageStart) / 1000.0
                    DURATION_DATA += "${duration},"
                    LATENCY_DATA += "${latency},"
                    STAGES_JSON += "'Authenticate to GCP',"
                    LAST_STAGE_END = System.currentTimeMillis()
                }
            }
        }

        stage('Push Application Image') {
            steps {
                script {
                    def now = System.currentTimeMillis()
                    def latency = (now - LAST_STAGE_END.toLong()) / 1000.0
                    def stageStart = now
                    echo "\n🚀 Latency since *Authenticate to GCP*: ${String.format('%.2f', latency)}s\n"
                    LATENCY_LOG += "Authenticate to GCP ➜ Push Application Image: ${String.format('%.2f', latency)}s\n"

                    def localImage = "${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    def remoteTag = "us-central1-docker.pkg.dev/${params.GCP_PROJECT_ID}/${params.AR_REPOSITORY}/${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG}"
                    echo "📦 Tagging local image and pushing to Artifact Registry..."
                    sh "docker tag ${localImage} ${remoteTag}"
                    sh "docker push ${remoteTag}"

                    def duration = (System.currentTimeMillis() - stageStart) / 1000.0
                    DURATION_DATA += "${duration},"
                    LATENCY_DATA += "${latency},"
                    STAGES_JSON += "'Push Application Image',"
                    LAST_STAGE_END = System.currentTimeMillis()
                }
            }
        }
    }

    post {
        always {
            script {
                def totalTime = (System.currentTimeMillis() - START_TIME.toLong()) / 1000.0
                echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "🌟 PIPELINE LATENCY SUMMARY"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "${LATENCY_LOG.trim()}"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "🏁 Total Pipeline Duration: ${String.format('%.2f', totalTime)} seconds"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

                // --- Generate HTML Report ---
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
  Total Pipeline Duration: <strong>${String.format('%.2f', totalTime)}s</strong></p>

  <h2>Stage Summary</h2>
  <table>
    <thead><tr><th>Stage</th><th>Duration (s)</th><th>Latency from Previous (s)</th></tr></thead>
    <tbody>
      <tr><td>🏗️ Build Application Image</td><td>${String.format('%.2f', DURATION_DATA.tokenize(',')[0] ?: 0)}</td><td>${String.format('%.2f', LATENCY_DATA.tokenize(',')[0] ?: 0)}</td></tr>
      <tr><td>🌐 Authenticate to GCP</td><td>${String.format('%.2f', DURATION_DATA.tokenize(',')[1] ?: 0)}</td><td>${String.format('%.2f', LATENCY_DATA.tokenize(',')[1] ?: 0)}</td></tr>
      <tr><td>🚀 Push Application Image</td><td>${String.format('%.2f', DURATION_DATA.tokenize(',')[2] ?: 0)}</td><td>${String.format('%.2f', LATENCY_DATA.tokenize(',')[2] ?: 0)}</td></tr>
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
    const latencyCtx = document.getElementById('latencyChart');
    new Chart(latencyCtx, {
      type: 'bar',
      data: {
        labels: ['Checkout→Build','Build→Auth','Auth→Push'],
        datasets: [{
          label: 'Latency (s)',
          data: [${LATENCY_DATA.trim().replaceAll(',$','')}],
          backgroundColor: ['#63b3ed','#fc8181','#ed8936']
        }]
      },
      options: { scales: { y: { beginAtZero: true } } }
    });

    const durationCtx = document.getElementById('durationChart');
    new Chart(durationCtx, {
      type: 'bar',
      data: {
        labels: ['Build','Auth','Push'],
        datasets: [{
          label: 'Duration (s)',
          data: [${DURATION_DATA.trim().replaceAll(',$','')}],
          backgroundColor: ['#48bb78','#4299e1','#ed8936']
        }]
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
