.PHONY: run clean help

help:
	@echo ""
	@echo "  make run     Start the cluster and deploy SynergyChat"
	@echo "  make clean   Stop and delete the minikube cluster"
	@echo ""

run:
	@./scripts/bootstrap.sh

clean:
	@sudo pkill -f "^minikube tunnel( |$$)" || true
	@minikube stop && minikube delete
	@sudo sed -i '/synchat\.internal/d;/synchatapi\.internal/d' /etc/hosts
	@echo "✔ Cluster cleaned up."