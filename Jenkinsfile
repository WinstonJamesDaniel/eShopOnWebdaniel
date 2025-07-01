pipeline {
  agent any

  environment {
    TEST_JSON  = "testcases.json"
    GITHUB_TOKEN = credentials('github-pat2')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Generate Testcases (mock)') {
      steps {
        // Here we “mock” your RAG generator: create testcases.json
        sh """
          cat > ${env.TEST_JSON} << 'EOF'
          {
            "tests": [
              {
                "id": "TC_001",
                "name": "Mock Test",
                "assembly": "Mock.Tests.dll",
                "class": "Mock.Tests.Class1",
                "method": "Test1",
                "expectedResult": "Pass"
              }
            ]
          }
          EOF
        """
      }
    }

    stage('Run .NET Tests') {
      steps {
        // Assuming you have solution & test projects in the repo
        bat 'dotnet test eShopOnWeb.sln  --logger "trx;LogFileName=test_results.trx"'
      }
      post {
        always {
          junit '**/TestResults/*.trx'
        }
      }
    }

    stage('Report to GitHub') {
      steps {
        script {
          // Use GitHub Commit Status Setter plugin
          // Mark build status on the commit/PR
          step([$class: 'GitHubCommitStatusSetter',
            context: 'ci/jenkins',
            statusResultSource: [$class: 'ConditionalStatusResultSource',
              results: [
                [$class: 'AnyBuildResult', state: 'ERROR', message: 'Build error'],
                [$class: 'AnyBuildResult', state: 'FAILURE', message: 'Tests failed'],
                [$class: 'AnyBuildResult', state: 'SUCCESS', message: 'All tests passed']
              ]
            ]
          ])
        }
      }
    }
  }

  post {
    always {
      // Clean up the temp JSON
      deleteFile "${env.TEST_JSON}"
    }
  }
}
