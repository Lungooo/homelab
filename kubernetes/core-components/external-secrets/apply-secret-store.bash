cat secret-store.yaml |\
  sed -e "s|<path:bitwardenids#organizationid>|${ORGANIZATION_ID}|g" \
  -e "s|<path:bitwardenids#projectid>|${PROJECT_ID}|g" |\
  kubectl apply -f -
