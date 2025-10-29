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

    environment {
        REPORT_FILE = "latency-report.html"
    }

    stages {
        stage('Measure Latencies') {
            steps {
                script {
                    // store all stage metrics here
                    stageTimes = [:]
                }
            }
        }

        stage('Checkout') {
            steps {
                script {
                    stageTimes['Checkout'] = [:]
                    stageTimes['Checkout'].start = System.currentTimeMillis()
                    echo "📦 Checking out source code..."
                    checkout scm
                    stageTimes['Checkout'].end = System.currentTimeMillis()
                }
            }
        }

        stage('Build Application Image') {
            steps {
                script {
                    def prevEnd = stageTimes['Checkout'].end
                    stageTimes['Build'] = [:]
                    stageTimes['Build'].start = System.currentTimeMillis()
                    stageTimes['Build'].latency = (stageTimes['Build'].start - prevEnd) / 1000.0
                    echo "⏱️ Latency since Checkout: ${String.format('%.2f', stageTimes['Build'].latency)}s"

                    echo "🏗️ Building application image..."
                    sh "docker build -t ${params.IMAGE_NAME_TO_SCAN}:${params.IMAGE_TAG} -f ./Dockerfile ."

                    stageTimes['Build'].end = System.currentTimeMillis()
                    stageTimes['Build'].duration = (stageTimes['Build'].end - stageTimes['Build'].start) / 1000.0
                }
            }
        }

        stage('Authenticate to GCP') {
            steps {
                script {
                    def prevEnd = stageTimes['Build'].end
                    stageTimes['Auth'] = [:]
                    stageTimes['Auth'].start = System.currentTimeMillis()
                    stageTimes['Auth'].latency = (stageTimes['Auth'].start - prevEnd) / 1000.0
                    echo "🌐 Latency since Build Application Image: ${String.format('%.2f', stageTimes['Auth'].latency)}s"

                    withCredentials([file(credentialsId: 'GCP_CREDENTIALS', variable: 'GCP_KEY_FILE')]) {
                        sh "gcloud auth activate-service-account --key-file=\"$GCP_KEY_FILE\""
                        sh 'gcloud auth list'
                        sh 'gcloud auth configure-docker gcr.io --quiet'
                        sh 'gcloud auth configure-docker us-central1-docker.pkg.dev --quiet'
                        echo "🔍 Running scanner container..."
                        def exitCode = sh(script: "docker ps > /dev/null", returnStatus: true)
                        if (exitCode != 0 && !params.IGNORE_SERVER_ERRORS) {
                            error("❌ GCP auth failed.")
                        }
                    }

                    stageTimes['Auth'].end = System.currentTimeMillis()
                    stageTimes['Auth'].duration = (stageTimes['Auth'].end - stageTimes['Auth'].start) / 1000.0
                }
            }
        }

        stage('Push Application Image') {
            steps {
                script {
                    def prevEnd = stageTimes['Auth'].end
                    stageTimes['Push'] = [:]
                    stageTimes['Push'].start = System.currentTimeMillis()
                    stageTimes['Push'].latency = (stageTimes['Push'].start - prevEnd) / 1000.0
                    echo "🚀 Latency since Authenticate to GCP: ${String.format('%.2f', stageTimes['Push'].latency)}s"

                    echo "⬆️  Pushing image to Artifact Registry..."
                    sh "echo 'Simulated docker push success.'"

                    stageTimes['Push'].end = System.currentTimeMillis()
                    stageTimes['Push'].duration = (stageTimes['Push'].end - stageTimes['Push'].start) / 1000.0
                }
            }
        }
    }

    post {
        always {
            script {
                def totalDuration = (stageTimes['Push'].end - stageTimes['Checkout'].start) / 1000.0

                def stages = ['Build', 'Auth', 'Push']
                def latencies = stages.collect { stageTimes[it].latency ?: 0 }
                def durations = stages.collect { stageTimes[it].duration ?: 0 }

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
  Total Duration: <strong>${String.format('%.2f', totalDuration)}s</strong></p>

  <h2>Stage Summary</h2>
  <table>
    <thead><tr><th>Stage</th><th>Duration (s)</th><th>Latency (s)</th></tr></thead>
    <tbody>
      ${stages.collect { s -> "<tr><td>${s}</td><td>${String.format('%.2f', stageTimes[s].duration)}</td><td>${String.format('%.2f', stageTimes[s].latency)}</td></tr>" }.join('\n')}
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
        labels: ${stages},
        datasets: [{ label: 'Latency (s)', data: ${latencies}, backgroundColor: ['#63b3ed','#fc8181','#ed8936'] }]
      },
      options: { scales: { y: { beginAtZero: true } } }
    });

    new Chart(document.getElementById('durationChart'), {
      type: 'bar',
      data: {
        labels: ${stages},
        datasets: [{ label: 'Duration (s)', data: ${durations}, backgroundColor: ['#48bb78','#4299e1','#ed8936'] }]
      },
      options: { scales: { y: { beginAtZero: true } } }
    });
  </script>
</body>
</html>
"""
                writeFile file: REPORT_FILE, text: html
                publishHTML([reportDir: '.', reportFiles: REPORT_FILE, reportName: 'Latency Report', keepAll: true])
            }
        }
    }
}
