<?php

/*
 * This file is part of the Neos.Neos package.
 *
 * (c) Contributors of the Neos Project - www.neos.io
 *
 * This package is Open Source Software. For the full copyright and license
 * information, please view the LICENSE file which was distributed with this
 * source code.
 */

declare(strict_types=1);

namespace Neos\Neos\FrontendRouting\DimensionResolution\Resolver;

use Neos\ContentRepository\DimensionSpace\Dimension\ContentDimension;
use Neos\ContentRepository\Factory\ContentRepositoryIdentifier;
use Neos\ContentRepositoryRegistry\ContentRepositoryRegistry;
use Neos\Neos\FrontendRouting\DimensionResolution\DimensionResolverFactoryInterface;
use Neos\Neos\FrontendRouting\DimensionResolution\DimensionResolverInterface;

/** @codingStandardsIgnoreStart */
use Neos\Neos\FrontendRouting\DimensionResolution\Resolver\AutoUriPathResolver\AutoUriPathResolverConfigurationException;
/** @codingStandardsIgnoreEnd */
use Neos\Neos\FrontendRouting\DimensionResolution\Resolver\UriPathResolver\Segment;
use Neos\Neos\FrontendRouting\DimensionResolution\Resolver\UriPathResolver\SegmentMapping;
use Neos\Neos\FrontendRouting\DimensionResolution\Resolver\UriPathResolver\SegmentMappingElement;
use Neos\Neos\FrontendRouting\DimensionResolution\Resolver\UriPathResolver\Segments;
use Neos\Neos\FrontendRouting\DimensionResolution\Resolver\UriPathResolver\Separator;


/**
 * @api
 */
final class AutoUriPathResolverFactory implements DimensionResolverFactoryInterface
{
    public function __construct(
        private readonly ContentRepositoryRegistry $contentRepositoryRegistry
    ) {
    }

    /**
     * @param array<string,mixed> $dimensionResolverOptions
     */
    public function create(
        ContentRepositoryIdentifier $contentRepositoryIdentifier,
        array $dimensionResolverOptions
    ): DimensionResolverInterface {
        $autoUriPathResolverFactoryInternals = $this->contentRepositoryRegistry->getService(
            $contentRepositoryIdentifier,
            new AutoUriPathResolverFactoryInternalsFactory()
        );
        $contentDimensions = $autoUriPathResolverFactoryInternals
            ->contentDimensionSource
            ->getContentDimensionsOrderedByPriority();

        if (count($contentDimensions) >= 2) {
            throw new AutoUriPathResolverConfigurationException(
                'The AutoUriPathResolverFactory is only meant for single-dimension use cases.'
                    . ' For everything more advanced, please manually configure UriPathResolver in Settings.yaml.'
            );
        }

        $contentDimension = reset($contentDimensions);
        assert($contentDimension instanceof ContentDimension);
        $mapping = [];
        foreach ($contentDimension->values as $value) {
            // we'll take the Dimension Value as Uri Path Segment value.
            $mapping[] = SegmentMappingElement::create($value, $value->value);
        }

        $segments = Segments::create(
            Segment::create(
                $contentDimension->identifier,
                SegmentMapping::create(...$mapping)
            )
        );

        return UriPathResolver::create(
            $segments,
            Separator::fromString('-'),
            $autoUriPathResolverFactoryInternals->contentDimensionSource
        );
    }
}