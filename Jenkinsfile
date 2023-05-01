pipeline {
//  agent any
    agent {
            kubernetes {
                yaml """
            apiVersion: v1
            kind: Pod
            metadata:
            labels:
                // some-label: some-label-value
                jenkins: slave
            spec:
              //serviceAccountName: jenkins-agent-pods
              serviceAccountName: jenkins
              containers:
              - name: aws-sam-cli
                //image: 023910024771.dkr.ecr.eu-west-1.amazonaws.com/amazon/aws-cli:latest
                image: nginx
                command:
                - cat
                tty: true
              - name: terraform
                image: nginx
                command:
                - cat
                tty: true
                resources:
                  requests:
                    memory: "0.2G"
                    cpu: "0.1"
              - name: jnlp
                image: 'nginx'
            """
            }
        }

  parameters {
    string(name: 'functionName', description: 'Provide the Lambda function for validation')
  }

  environment {
        REGION = 'us-east-1'
  }

  stages {

    stage('Build and Run unit tests') {
        when {
          anyOf {
            branch "develop";
            changeRequest target: 'develop';
            tag "v*"
          }
        }
        steps {
          container('aws-sam-cli') {
              ansiColor('xterm') {
                  sh '''

                  echo " ------ Testing Transform Job Input Lambda ------ "
                  cd transform_job_input
                  export PYTHONPATH = "${PYTHONPATH}": $PWD / src
                  pip install - r tests / requirements.txt
                  python - W ignore - m pytest tests / unit
                  /* -v --log-cli-level=INFO --junit-xml test_results.xml
                                 unset PYTHONPATH
                                 cd ..

                                '''
                              }   
                            }
                          }
                      }

                      stage('Pre-Deploy Lambda Version Check') {
                       // when { anyOf {branch "develop";changeRequest target: 'develop'; tag "v*"; branch "feature/*"; branch "main/*" } }
                          steps {
                            container('aws-cli') {
                              script {
                                  data = sh (
                                          script: "aws --region ${REGION} lambda list-functions",
                                          returnStdout: true
                  		).trim()
                  		//Check if Lambda function exists
                  		def function_list = readJSON(text: data)
                  		function_list.Functions.each {
                  		  if ("${it.FunctionName}" == "${params.functionName}") {
                  		  println "Function ${params.functionName} is deployed"
                  		  isFunctionDeployed = true
                  		  }
                  		  else {
                  		  echo "Function ${params.functionName} does not exist"
                  		  }
                  		}
                  		//Check if Lambda Alias exists
                  		if (isFunctionDeployed) {
                  		  data = sh (
                                           script: "aws --region ${REGION} lambda list-aliases --function-name ${params.functionName}",
                                           returnStdout: true
                  	          ).trim()
                                     def alias_list = readJSON(text: data)
                                     if (!alias_list.Aliases.isEmpty()) {
                                        alias_list.Aliases.each {
                                          if ("${it.Name}" == "${params.aliasName}") {
                                             echo "Alias ${params.aliasName} for Lambda Function ${params.functionName} is deployed"
                                             isAliasDeployed = true
                                              } else {
                                                echo "Alias ${params.aliasName} for Lambda Function ${params.functionName} does not exist"
                  			      }
                  			    }
                  	        //Check highest Lambda version i.e. oldVersion
                  		if (isAliasDeployed) {
                                                data = sh (
                                                      script: "aws --region ${REGION} lambda list-versions-by-function --function-name ${params.functionName}",
                                                      returnStdout: true
                                               ).trim()
                                                def old_version_list = readJSON(text: data)
                                                def old_versions = []
                                                old_version_list.Versions = old_version_list.Versions.tail()
                                                old_version_list.Versions.each {
                                                  old_versions.add(it.Version.toInteger())
                                                }
                                                oldVersion = old_versions.max()
                                                echo "Old version of Lambda function ${params.functionName} is ${oldVersion}"

                                              } else {
                                                echo "Alias ${params.aliasName} does not exist, skipping version check"

                  			      }
                  			    }
                  			  }
                  		        }
                  	              }
                                    }
				  }
                      
                      stage('Create lambda artifacts') {
                        when { anyOf {branch "develop";changeRequest target: 'develop'; tag "v*"; branch "feature/*" } }
                          steps {
                            container('aws-sam-cli') {
                              ansiColor('xterm') {  
                              sh '''

                                echo "----- Printing versions -----"
                                sam --version 
                                aws --version
                                python --version


                                echo "----- Building Transform Job Input Lambda ------"
                                cd transform_job_input
                                sam build --template template.yaml
                                cd ..

                                '''
                              }
                            }    
                          }
                      }
                   
                      stage('Zip and Upload artifact') {
                        when { anyOf { tag "v*"; branch "feature/*" }}
                          steps {
                            container('aws-sam-cli') {
                              ansiColor('xterm') {   
                              sh '''

                                echo " ----- Zip Transform Job Input Lambda artifact ----- "
                                cd transform_job_input
                                cd .aws-sam/build/transformJobInput
                                zip -rqq ../../../transformJobInput.zip *
                                cd ../../../

                                echo " ----- Upload Transform Job Input Lambda LAMBDA ${TAG_NAME} to S3 bucket ----- "
                                aws s3 cp transformJobInput.zip s3://ts-ml-platform-artifacts-eu-west-1/mle_lambda_ose/${TAG_NAME}/transformJobInput.zip
                                aws s3 cp transformJobInput.zip s3://ts-ml-platform-artifacts-${REGION}/mle_lambda_ose/${TAG_NAME}/transformJobInput.zip
                                cd ..

                                '''           
                              }
                            }
                          }
                      }
                    }
                  }
