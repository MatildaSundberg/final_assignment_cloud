from utils import util_functions as u

def transfer_json_file(pem_file_path):
    orchestrator_instance_id = u.get_orchestrator_instance_id()
    if orchestrator_instance_id:
        print(f"Orchestrator instance ID: {orchestrator_instance_id}")

    u.transfer_file_to_ec2(orchestrator_instance_id, "resources/test.json" , "/home/ubuntu/test.json", pem_file_path)