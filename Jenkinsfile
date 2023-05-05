// If this list grows any bigger move it to SSM
def getEnvAccountNumber(env) {
    // Clean up env name to allow for key lookup
    thisEnv = env.replaceAll("-","")
    def accountMap = [
        dev: "036140576280",
        qa: "575873681961",
        stg: "053548589897",
        prod: "913388582969",
       // osedev: "164375936220",
        osedev: "412857254796",
        oseqa: "788119114344",
        osestg: "961665515316",
        oseprod: "951502535150",
        infra: "023910024771"
    ]
    return accountMap[thisEnv]
}

def getPromoteFromEnv(env) {
    // selects the env to promote assets from based on the previous env
    thisEnv = env.replaceAll("-","")
    def promoteFromEnvMap = [
        qa: "dev",
        stg: "qa",
        prod: "stg",
        oseqa: "osedev",
        osestg: "oseqa",
        oseprod: "osestg"
    ]
    return promoteFromEnvMap[thisEnv]
}

pipeline {
    agent {
        kubernetes {

           yaml """
        apiVersion: v1
        kind: Pod
        metadata:
        labels:
            deployment-runner: mle-ose-infra
        spec:
        serviceAccountName: jenkins-agent-pods
        containers:
        - name: aws-cli
            //image: 023910024771.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-cli:latest
            image: amazon/aws-cli
            command:
            - cat
            tty: true
        - name: terraform
            //image: 023910024771.dkr.ecr.us-east-1.amazonaws.com/terraform:latest
            image: hasicorp/terraform
            command:
            - cat
            tty: true
            resources:
            requests:
                memory: "0.2G"
                cpu: "0.1"
        - name: jnlp
            image: 'jenkins/inbound-agent'
        """    

            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    deployment-runner: mle-ose-infra
spec:
  //serviceAccountName: jenkins-agent-pods
  serviceAccountName: jenkins
  containers:
    - name: aws-cli
      //image: 023910024771.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-cli:latest
      image: amazon/aws-cli
      command:
        - cat
      tty: true
    - name: terraform
      //image: 023910024771.dkr.ecr.us-east-1.amazonaws.com/terraform:latest
      image: terraform
      command:
        - cat
      tty: true
      resources:
        requests:
          memory: "0.2G"
          cpu: "0.1"
    - name: jnlp
      //image: 023910024771.dkr.ecr.us-east-1.amazonaws.com/jenkins/inbound-agent:latest
        image: 'jenkins/inbound-agent'
        """

        }
    }

    parameters {
        string(name: 'ENV', description: 'Select environment to apply changes to. Valid Values are osedev,oseqa,osestg,oseprod', defaultValue: "osedev")
        string(name: 'Environment', description: 'Provide the environment name, this will be used for tfvars file', defaultValue: "dev")
      //  choice(name: 'ENV', choices: ['osedev', 'oseqa', 'osestg', 'oseprod'], description: 'Select environment to apply changes to', defaultValue: "osedev")
      //  choice(name: 'PROMOTE_FROM_ENV', choices: ['osedev', 'oseqa', 'osestg', 'oseprod'], description: 'Select environment to apply changes to')
    }

    environment{
        ACCOUNT_NUMBER = getEnvAccountNumber(params.ENV)
        ENV = "${params.ENV}"
        PROMOTE_FROM_ENV = getPromoteFromEnv(params.ENV)
        PROMOTE_FROM_ENV_ACCOUNT_NUMBER = getEnvAccountNumber(params.PROMOTE_FROM_ENV)
        AWS_DEFAULT_REGION = "us-east-1"
        BRANCH_NAME = "feature/PD-73955-Add-step-for-terraform-apply"
    }

    stages {

        stage('Configure Build Env') {
           steps {
                script {
                    // Reads file by leveraging the 'Pipeline Utility Steps' plugin
                    readProperties(file: "tf/env_vars/${params.Environment}-us-east-1.tfvars").each { key, value -> env[key] = value }
                }
            }
        }

        stage('AWS S3 Lambda Asset Promotion') {
	 when { anyOf {branch "dev";branch "qa";branch "stg";branch "prod";changeRequest() } }
            steps {
                script {
                    sh """ #!/bin/bash

                        # Assume role into $PROMOTE_FROM_ENV - $PROMOTE_FROM_ENV_ACCOUNT_NUMBER
                        aws sts get-caller-identity
                        echo "[INFO] - Assume the cross account JenkinsDeployment role into $PROMOTE_FROM_ENV_ACCOUNT_NUMBER"
                        set +x
                        . ./scripts/jenkins/assume-role.sh $PROMOTE_FROM_ENV_ACCOUNT_NUMBER
                        set -x
                        aws sts get-caller-identity

                        # Copy down latest assets
                        aws s3 cp --recursive s3://mle-ts-nextgen-ose-$PROMOTE_FROM_ENV/lambda_ose .
                        
                        # clear current role assumption
                        unset AWS_ACCESS_KEY_ID
                        unset AWS_SECRET_ACCESS_KEY
                        unset AWS_SESSION_TOKEN

                        # Assume role into $ENV
                        aws sts get-caller-identity
                        echo "[INFO] - Assume the cross account JenkinsDeployment role into $ACCOUNT_NUMBER"
                        set +x
                        . ./scripts/jenkins/assume-role.sh
                        set -x
                        aws sts get-caller-identity

                        # Copy PROMOTE_FROM_ENV_ACCOUNT from env assets
                        aws s3 cp --recursive ./ose-$PROMOTE_FROM_ENV s3://mle-ts-nextgen-ose-$ENV/lambda_ose
                    """
                }
            }
        }

        stage('Get Pre-Deployment Lambda Version') {
            steps {
                script {
                    sh("echo 'check version'")
                }
            }
        }

    stage('TF init & validate global') {
 //    when { anyOf {branch "feature/*";branch "dev";branch "qa";branch "stg";branch "prod";changeRequest() } }
      steps {
//	 withAWS(role: 'JenkinsDeployment', roleAccount: "${ACCOUNT_NUMBER}") {
          container('terraform') {
            ansiColor('xterm') {
              sh '''
                set +x
                if [ -d "tf" ]; then
                  cd tf
                  terraform init
                  terraform validate
                else
                  echo "*************** SKIPPING INIT ******************"
                  echo "Terraform tf folder does not exist"
                  echo "*************************************************"
                fi
              '''
            }
          }
        }
      }
 //   }

    stage('TF plan global') {
  //   when { anyOf {branch "feature/*";branch "dev";branch "qa";branch "stg";branch "prod";changeRequest() } }
      steps {
//	withAWS(role: 'JenkinsDeployment', roleAccount: "${ACCOUNT_NUMBER}") {
          container('terraform') {
            script  {
              def retVal = sh(returnStatus: true, script: '''
                set +x
                if [ -d "tf" ]; then
                  cd tf
                  terraform plan -detailed-exitcode
                  exit
                else
                  echo "*************** SKIPPING PLAN ******************"
                  echo "Terraform tf folder does not exist."
                  echo "*************************************************"
                fi
              ''')
             }
           }
         }
      }
 //   }

    stage('Approval global') {
   //   when { anyOf {branch "feature/*";branch "dev";branch "qa";branch "stg";branch "prod";changeRequest() } }
      steps {
        script {
          def userInput = input(id: 'confirm', message: 'Apply Terraform?', parameters: [ [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Apply terraform', name: 'confirm'] ])
        }
      }
    }

    stage('TF Apply global') {
   //   when { anyOf {branch "dev";branch "qa";branch "stg";branch "prod";changeRequest() } }
      steps {
//	withAWS(role: 'JenkinsDeployment', roleAccount: "${ACCOUNT_NUMBER}") {
          container('terraform') {
            ansiColor('xterm') {
              sh '''
                set +x
                cd tf
                terraform apply -input=false -auto-approve
              '''
            }
          }
        }
      }
 //   }

        stage('Get Post-Deployment Lambda Version') {
            steps {
                script {
                    sh("echo 'check version'")
                }
            }
        }


        stage('Run Tests') {
	when { anyOf {branch "dev";branch "qa";branch "stg";branch "prod";changeRequest() } }
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
