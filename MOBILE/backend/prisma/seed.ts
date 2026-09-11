import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding RIHLAH database...');

  // ── Default fare formula (version 1) ──────────────────────────────────────
  await prisma.fareFormula.upsert({
    where: { version: 1 },
    update: {},
    create: {
      version: 1,
      baseCar: 5000,
      perKmCar: 3000,
      perMinCar: 300,
      baseBike: 3000,
      perKmBike: 2000,
      perMinBike: 200,
      baseSend: 4000,
      perKmSend: 2500,
      perMinSend: 250,
      platformFeeRate: 0.05,
      maxKmCar: 50,
      maxKmBike: 25,
      maxKmSend: 30,
      validFrom: new Date('2026-01-01'),
    },
  });
  console.log('✓ Default fare formula (v1) seeded');

  // ── Service areas (Bandung Kota + Cimahi) ────────────────────────────────
  const bandungGeojson = {
    type: 'Polygon',
    coordinates: [
      [
        [107.55, -6.80],
        [107.72, -6.80],
        [107.72, -6.97],
        [107.55, -6.97],
        [107.55, -6.80],
      ],
    ],
  };

  await prisma.serviceArea.upsert({
    where: { id: 'bandung-kota' },
    update: {},
    create: {
      id: 'bandung-kota',
      name: 'Bandung Kota',
      geojson: bandungGeojson,
      active: true,
    },
  });

  const cimahiGeojson = {
    type: 'Polygon',
    coordinates: [
      [
        [107.50, -6.85],
        [107.57, -6.85],
        [107.57, -6.92],
        [107.50, -6.92],
        [107.50, -6.85],
      ],
    ],
  };

  await prisma.serviceArea.upsert({
    where: { id: 'cimahi' },
    update: {},
    create: {
      id: 'cimahi',
      name: 'Cimahi',
      geojson: cimahiGeojson,
      active: true,
    },
  });
  console.log('✓ Service areas seeded (Bandung Kota, Cimahi)');

  // ── Default promo codes ──────────────────────────────────────────────────
  const promos = [
    {
      code: 'RIHLAH10',
      title: 'Diskon 10% First Ride',
      description: 'Potongan 10% untuk perjalanan pertama kamu',
      discountType: 'percent',
      discountValue: 10,
      minOrderIdr: 0,
      expiryLabel: 'Berlaku hingga 31 Des 2026',
    },
    {
      code: 'HEMAT20',
      title: 'Flat Rp 20.000',
      description: 'Potongan langsung Rp 20.000 untuk semua layanan',
      discountType: 'flat',
      discountValue: 20000,
      minOrderIdr: 50000,
      expiryLabel: 'Berlaku hingga 31 Des 2026',
    },
  ];

  for (const promo of promos) {
    const existing = await prisma.promo.findUnique({
      where: { code: promo.code },
    });
    if (!existing) {
      await prisma.promo.create({ data: promo });
    }
  }
  console.log('✓ Default promo codes seeded');

  console.log('\nSeed complete.');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
