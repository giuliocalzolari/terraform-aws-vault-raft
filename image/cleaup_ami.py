""" This script creates new AMIs and manages the lifecycle of older ones """
import operator
import boto3


AMI_LIFECYCLE = [  # Ordered by newest AMI
    dict(stage='Current', delete=False, unshare=False),
    dict(stage='Current', delete=False, unshare=False),
    dict(stage='Deprecated', delete=False, unshare=False),
    dict(stage='Obselete', delete=False, unshare=False),
    dict(stage='Deleted', delete=False, unshare=True),
    dict(stage='Purged', delete=True, unshare=True),
]
client = boto3.client('ec2')

def main():
    manage_lifecycle('x86_64')
    manage_lifecycle('arm64')


def manage_lifecycle(arch):
    response = client.describe_images(
        Filters=[
            {
                'Name': 'architecture',
                'Values': [arch],
            },
            {
                'Name': 'name',
                'Values': ['vault-*'],
            },
        ],
        Owners=['self'],
    )
    images_list = response['Images']
    images_list.sort(key=operator.itemgetter('CreationDate'), reverse=True)
    ami_verions = {}
    print('==[{}] {} images found '.format(arch, len(images_list)))
    for image in images_list:
        version = image['Name'].split('-')[1]
        if version not in ami_verions.keys():
            ami_verions[version] = []
        ami_verions[version].append(image)

    for version, images in ami_verions.items():
        print('===[{}][{}] {} images found '.format(arch, version, len(images)))
        for idx, image in enumerate(images):
            if idx >= len(AMI_LIFECYCLE):  # Out of lifecylce
                delete_image(image)
                continue
            lifecycle = AMI_LIFECYCLE[idx]
            if lifecycle['delete']:
                delete_image(image)
                continue
            if lifecycle['unshare']:
                unshare_image(image)
            tag_image(image, dict(
                Stage=lifecycle['stage'],
            ))


def tag_image(image_info, tags):
    print ('==== Tagging image %s with the following tags: %s'
           % (image_info['Name'], str(tags)))
    client.create_tags(
        Resources=[
            image_info['ImageId'],
        ],
        Tags=[
            {'Key': key, 'Value': val}
            for key, val in tags.items()
        ],
    )


def unshare_image(image_info):
    print('==== Unsharing image %s' % image_info['Name'])
    response = client.describe_image_attribute(
        Attribute='launchPermission',
        ImageId=image_info['ImageId'],
    )
    if 'LaunchPermissions' in response and response['LaunchPermissions']:
        perms = response['LaunchPermissions']
        rs = client.modify_image_attribute(
            Attribute='LaunchPermission',
            ImageId=image_info['ImageId'],
            LaunchPermission={
                'Remove': [
                    {
                        'Group': 'all',
                        'UserId': perm['UserId']
                    }
                    for perm in perms
                ]
            },
            OperationType='remove',
        )


def delete_image(image_info):
    print('==== Deleteing image %s' % (image_info['Name']))
    client = boto3.client('ec2')
    client.deregister_image(ImageId=image_info['ImageId'])
    for device in image_info['BlockDeviceMappings']:
        snapshot_id = device['Ebs']['SnapshotId']
        client.delete_snapshot(SnapshotId=snapshot_id)





# def parse_args():
#     parser = argparse.ArgumentParser(
#         description='Create and manage AMI lifecycle.',
#     )
#     parser.add_argument(
#         '-a', '--ami', nargs='*', default=DEFAULT_AMIS, dest='amis',
#         help='One or more AMI names. Should have a corresponding <name>.json',
#     )
#     parser.add_argument(
#         '-o', '--owner', default=DEFAULT_OWNER,
#         help='Account ID of the owner of the AMI',
#     )
#     parser.add_argument(
#         '--lifecycle-only', action='store_true',
#         help='Do not create new AMIs. Only manage the lifecycle of old ones',
#     )
#     return parser.parse_args()


if __name__ == '__main__':
    main()
