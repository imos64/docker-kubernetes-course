# frontend connects to backend, both deployed in the same AZ.

# affinity: 
# nodeAffinity:
#   requiredDuringSchedulingIgnoredDuringExecution:
#     nodeSelectorTerms:
#     - matchExpressions:
#       - key: topology.kubernetes.io/zone
#         operator: In
#         values:
#         - westus2-1
#         - westus2-2
#         - westus2-3
#   requiredDuringSchedulingIgnoredDuringExecution:
#     nodeSelectorTerms:
#     - matchExpressions:
#       - key: agentpool
#         operator: In
#         values:
#         - espoolz1
#         - espoolz2
#         - espoolz3