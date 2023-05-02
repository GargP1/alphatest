// If this list grows any bigger move it to SSM
def getEnvAccountNumber(env) {
    // Clean up env name to allow for key lookup
    thisEnv = env.replaceAll("-","")
    def accountMap = [
        dev: "036140576280",
        qa: "575873681961",
        stg: "053548589897",
        prod: "913388582969",
        osedev: "164375936220",
        oseqa: "788119114344",
        osestg: "961665515316",
        oseprod: "951502535150",
        test: "412857254796",
        infra: "023910024771"
    ]
    return accountMap[thisEnv]
}

pipeline {
//    agent {
//        kubernetes {
//            yaml """
//        apiVersion: v1
//        kind: Pod
//        metadata:
//        labels:
//            deployment-runner: mle-ose-infra
//        spec:
//        serviceAccountName: jenkins-agent-pods
//        containers:
//        - name: aws-cli
//            image: 023910024771.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-cli:latest
//            command:
//            - cat
//            tty: true
//        - name: terraform
//            image: 023910024771.dkr.ecr.us-east-1.amazonaws.com/terraform:latest
//            command:
//            - cat
//            tty: true
//            resources:
//            requests:
//                memory: "2G"
//                cpu: "1"
//        - name: jnlp
//            image: '023910024771.dkr.ecr.us-east-1.amazonaws.com/jenkins/inbound-agent:latest'
//        """    
//        }
//    }
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
              - name: aws-cli
                //image: 023910024771.dkr.ecr.eu-west-1.amazonaws.com/amazon/aws-cli:latest
                image: amazon/aws-cli
                command:
                - cat
                tty: true
              - name: terraform
                image: hashicorp/terraform
                command:
                - cat
                tty: true
                resources:
                  requests:
                    memory: "0.2G"
                    cpu: "0.1"
              - name: jnlp
                image: jenkins/inbound-agent
            """
            }
        }

    parameters {
        choice(name: 'ENV', choices: ['osedev', 'oseqa', 'osestg', 'oseprod', 'test'], description: 'Select environment to apply changes to')
    }

    environment{
        ACCOUNT_NUMBER = getEnvAccountNumber(params.ENV)
        ENV = "${params.ENV}"
        AWS_DEFAULT_REGION = "us-east-1"
        BRANCH_NAME = "main"
    }

    stages {

   //     stage('Configure Build Env') {
  //         steps {
   //             script {
    //                // Reads file by leveraging the 'Pipeline Utility Steps' plugin
    //                readProperties(file: "tf/env_vars/${BRANCH_NAME}.env").each { key, value -> env[key] = value }
    //            }
    //        }
    //    }

        stage('Get Pre-Deployment Lambda Version') {
            steps {
                script {
                    sh("echo 'check version'")
                }
            }
        }

    stage('TF init & validate global') {
      steps {
	// withAWS(role: 'JenkinsDeployment', roleAccount: "${ENV}") {
          container('terraform') {
            ansiColor('xterm') {
              sh '''
                set +x
                if [[ $CHANGE_TARGET ]]; then
                  TARGET_ENV=$CHANGE_TARGET
                else
                  TARGET_ENV=$BRANCH_NAME
                fi
                if [ -d "tf/envs/${TARGET_ENV}/global" ]; then
                  cd tf/envs/${TARGET_ENV}/global
                  export GIT_SSH_COMMAND="ssh -i $SSH_KEY -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
                  terraform init
                  terraform validate
                else
                  echo "*************** SKIPPING INIT ******************"
                  echo "Branch '$TARGET_ENV/global' does not represent an official environment."
                  echo "*************************************************"
                fi
              '''
            }
          }
        }
      }
    // }

    stage('TF plan global') {
      steps {
	//withAWS(role: 'JenkinsDeployment', roleAccount: "${ENV}") {
          container('terraform') {
            script {
              def retVal = sh(returnStatus: true, script: '''
                set +x
                if [[ $CHANGE_TARGET ]]; then
                  TARGET_ENV=$CHANGE_TARGET
                else
                  TARGET_ENV=$BRANCH_NAME
                fi
                if [ -d "tf/envs/${TARGET_ENV}/global" ]; then
                  cd tf/envs/${TARGET_ENV}/global
                  terraform plan -detailed-exitcode
                  exit
                else
                  echo "*************** SKIPPING PLAN ******************"
                  echo "Branch '$TARGET_ENV/global' does not represent an official environment."
                  echo "*************************************************"
                fi
              ''')
              if (retVal == 0) {
                runStageFlag = false
              }
            }
          }
        }
      }
    //}

    stage('Approval global') {
      when {
        anyOf {branch "main";branch "qa"; branch "stg"; branch "prod"}
        expression { return runStageFlag }
      }
      steps {
        script {
          def userInput = input(id: 'confirm', message: 'Apply Terraform?', parameters: [ [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Apply terraform', name: 'confirm'] ])
        }
      }
    }

    stage('TF Apply global') {
      when {
        anyOf {branch "main";branch "qa"; branch "stg"; branch "prod"}
        expression { return runStageFlag }
      }
      steps {
	//withAWS(role: 'JenkinsDeployment', roleAccount: "${ENV}") {
          container('terraform') {
            ansiColor('xterm') {
              sh '''
                set +x
                TARGET_ENV=$BRANCH_NAME
                cd tf/envs/${TARGET_ENV}/global
                terraform apply -input=false -auto-approve
              '''
            }
          }
        }
      }
    //}

        stage('Get Post-Deployment Lambda Version') {
            steps {
                script {
                    sh("echo 'check version'")
                }
            }
        }


        stage('Run Tests') {
            steps {
                container('aws-cli') {
                    script {
                        sh """ 
			    #!/bin/bash

                            # Assume role
                            aws sts get-caller-identity
                            echo "[INFO] - Assume the cross account JenkinsDeployment role into $ACCOUNT_NUMBER"
                            set +x
                            . ./scripts/jenkins/assume-role.sh
                            set -x
                            aws sts get-caller-identity 
                            
                            ######################################################
                            # TODO: boil down into custom container image
                            pyenv install 3.9.5
                            pyenv virtualenv 3.9.5 batch-transform-integration-env
                            pyenv activate batch-transform-integration-env
                            pip install -r requirements.txt
                            ######################################################

                            # POST-PYTEST MERGE
                            # pytest trigger_batch_step_function.py \
                            #    --model_package_arn arn:aws:sagemaker:us-east-1:$ACCOUNT_NUMBER:model-package/atum-score-2022-12-21-15-30-3/1 \
                            #    --input_data_key batch-transform-input/atum-score-2022-12-21-15-30-3/atum-score-2022-12-21-15-30-3.jsonl.gzip \
                            #    --reference_output_key batch-transform-output/atum-score-2022-12-21-15-30-3-demo/output/atum-score-2022-12-21-15-30-3-demo.jsonl.gzip.out \
                            #    --env $ENV \
                            #    --log-cli-level=INFO

                            python3 trigger_batch_step_function.py --bucket mle-ts-nextgen-ose-$ENV --trigger_rule "lds batch score trigger" --model_package_arn arn:aws:sagemaker:us-east-1:$ACCOUNT_NUMBER:model-package/atum-score-2022-12-21-15-30-3/1 --input_data_key batch-transform-input/atum-score-gz-2022-12-21-15-30-3/atum-score-2022-12-21-15-30-3.jsonl.gz --reference_output_key batch-transform-output/atum-score-2022-12-21-15-30-3-demo/output/atum-score-2022-12-21-15-30-3.jsonl.gzip.out
                        """
                    }
                }
            }
        }
    }
}
