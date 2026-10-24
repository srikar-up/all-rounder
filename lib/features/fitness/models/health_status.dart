enum HealthStatus {
  unsupported('Health Connect is not supported on this platform'),
  notInstalled('Health Connect is not installed on this device'),
  updateRequired('Health Connect needs to be updated'),
  needsPermission('Health permissions required'),
  ready('Connected and syncing'),
  error('Error connecting to Health Connect');

  final String description;
  const HealthStatus(this.description);
}
