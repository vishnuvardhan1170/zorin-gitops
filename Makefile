HELM = helm
CHART = helm
NS_DEV = zorin-dev
NS_PROD = zorin

.PHONY: lint template-dev template-prod diff-dev diff-prod

lint:
	$(HELM) lint $(CHART)
	$(HELM) template zorin $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-dev.yaml > /dev/null
	$(HELM) template zorin $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-prod.yaml > /dev/null

template-dev:
	$(HELM) template zorin $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-dev.yaml

template-prod:
	$(HELM) template zorin $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-prod.yaml

diff-dev:
	$(HELM) template zorin $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-dev.yaml | kubectl diff -f - -n $(NS_DEV)

diff-prod:
	$(HELM) template zorin $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-prod.yaml | kubectl diff -f - -n $(NS_PROD)   