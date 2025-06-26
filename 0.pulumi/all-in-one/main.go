package main

import (
	"fmt"

	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumiverse/pulumi-talos/sdk/go/talos/imagefactory"
	"gopkg.in/yaml.v3"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {

		talosVersion := "v1.10.4"
		platform := "metal"

		tmpYamlSchema, err := yaml.Marshal(map[string]interface{}{
			"customization": map[string]interface{}{
				"extraKernelArgs": []string{
					"net.ifnames=0",
				},
				"systemExtensions": map[string]interface{}{
					"officialExtensions": []string{
						"siderolabs/iscsi-tools",
						"siderolabs/util-linux-tools",
						"siderolabs/intel-ucode	",
					},
				},
			},
		})
		if err != nil {
			return err
		}

		schema, err := imagefactory.NewSchematic(ctx, "schematicResource", &imagefactory.SchematicArgs{
			Schematic: pulumi.String(tmpYamlSchema),
		})
		if err != nil {
			return err
		}

		schematicID := schema.ID().ApplyT(func(s pulumi.ID) (string, error) {
			ctx.Export("schematicIdRaw", pulumi.String(s))
			return string(s), nil
		}).(pulumi.StringOutput)

		ctx.Export("schematicId", schematicID)

		urlResult := imagefactory.GetUrlsOutput(ctx, imagefactory.GetUrlsOutputArgs{
			Platform:     pulumi.StringPtr(platform),
			TalosVersion: pulumi.String(talosVersion),
			SchematicId:  schematicID.ToStringOutput(),
		})

		qcow2Url := urlResult.SchematicId().ApplyT(func(schematicId string) (string, error) {
			ctx.Export("schematicId", pulumi.String(schematicId))
			return fmt.Sprintf("https://factory.talos.dev/image/%s/%s/%s-amd64.qcow2", schematicId, talosVersion, platform), nil
		})
		ctx.Export("imageUrl", urlResult.ToGetUrlsResultOutput().Urls().Installer())
		ctx.Export("qcow2Url", qcow2Url)
		return nil
	})
}
