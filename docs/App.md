# So far just supports for Hyperledger Fabric

## Usage
```shell
cd ./App/fabric
./app.sh
```

then
```shell
kubectl port-forward svc/fabric-rest-sample 3001:3000
```

```shell
curl --include --header "Content-Type: application/json" --header "X-Api-Key: 97834158-3224-4CE7-95F9-A148C886653E" http://localhost:3001/api/assets/5
```

## Jmeter
after port-forward, you are able to download jmeter and run jmeter test with sample at `App/fabric/jmeter/HTTPRequest.jmx`