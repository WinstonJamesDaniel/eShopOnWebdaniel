pipeline {
  agent any

  environment {
    // Will be used by the PS script
    TEST_JSON    = "testcases.json"
    RESULTS_XML  = "testResults.xml"
    GITHUB_TOKEN = credentials('github-pat2')
  }

  triggers {
    // fallback polling (already set on the job)
    pollSCM('* * * * *')
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Mock Generate Testcases') {
      steps {
        // create a dummy JSON for now
        writeFile file: "${env.TEST_JSON}", text: '''{
  "tests": [
    "eShopOnWebdaniel.tests.PublicApiIntegrationTests.AuthEndpoints.AuthenticateEndpoint.ReturnsExpectedResultGivenCredentials"
  ]
}'''
        echo "✅ Mocked ${env.TEST_JSON}"
      }
    }

    
    stage('Install trx2junit Tool') {
      steps {
        powershell '''
          if (!(Test-Path ".config/dotnet-tools.json")) {
            dotnet new tool-manifest
          }
    
          # Check if trx2junit is already installed
          $installed = dotnet tool list | Select-String "trx2junit"
    
          if (!$installed) {
            dotnet tool install trx2junit
            Write-Host "✅ trx2junit installed"
          } else {
            Write-Host "ℹ️ trx2junit already present"
          }
        '''
      }
    }


    stage('Build') {
      steps {
    bat '"C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\MSBuild\\Current\\Bin\\MSBuild.exe" eShopOnWebdaniel.sln /p:Configuration=Debug'
      }
    }
    stage('Run .NET Tests') {
      steps {
        // call your PS1 – pass the JSON and xml names
        powershell script: """
          .\\run‑tests.ps1 `
            -TestCasesFile '${env.TEST_JSON}' `
            -ResultsFile '${env.RESULTS_XML}'
        """, label: 'Execute PowerShell Tests'
      }
      post {
        always {
          // Publish in Jenkins UI
          junit allowEmptyResults: false, testResults: "${env.RESULTS_XML}"
        }
      }
    }

    stage('Report to GitHub PR') {
      when {
        // only on PRs
        expression { env.CHANGE_ID != null }
      }
      steps {
        script {
          // read pass/fail summary from the XML
          def report = junitKeepLongStdio?[]:[] // (we already published above)
          // for simplicity, post a comment
          def status = currentBuild.currentResult
          def repo = 'WinstonJamesDaniel/eShopOnWebdaniel'
          sh """
            curl -s -X POST \
              -H "Authorization: token ${env.GITHUB_TOKEN}" \
              -d '{ "body": "Build **${status}** on branch `${env.BRANCH_NAME}`. See [Jenkins Build #${env.BUILD_NUMBER}](${env.BUILD_URL})." }' \
              "https://api.github.com/repos/${repo}/issues/${env.CHANGE_ID}/comments"
          """
        }
      }
    }
  }

  post {
    always {
      // clean up temporary files
      deleteDir()   // or specifically: deleteFile TEST_JSON, RESULTS_XML
    }
  }
}
